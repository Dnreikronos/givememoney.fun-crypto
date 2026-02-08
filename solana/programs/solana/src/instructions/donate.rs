use anchor_lang::prelude::*;
use anchor_lang::system_program;
use crate::constants::*;
use crate::errors::StreamerDonationError;
use crate::events::DonationReceived;
use crate::state::{Config, Donation, Streamer};

#[derive(Accounts)]
pub struct Donate<'info> {
    #[account(
        seeds = [b"config"],
        bump = config.bump,
        constraint = !config.paused @ StreamerDonationError::Paused,
    )]
    pub config: Account<'info, Config>,

    #[account(
        mut,
        seeds = [b"streamer", streamer_wallet.key().as_ref()],
        bump = streamer.bump,
    )]
    pub streamer: Account<'info, Streamer>,

    #[account(
        init,
        payer = donor,
        space = 8 + Donation::INIT_SPACE,
        seeds = [
            b"donation",
            streamer_wallet.key().as_ref(),
            &streamer.donation_count.to_le_bytes(),
        ],
        bump,
    )]
    pub donation: Account<'info, Donation>,

    #[account(mut)]
    pub donor: Signer<'info>,

    /// CHECK: Validated via streamer PDA seeds; receives the streamer portion.
    #[account(
        mut,
        constraint = streamer_wallet.key() == streamer.wallet,
    )]
    pub streamer_wallet: AccountInfo<'info>,

    /// CHECK: Validated against config; receives the fee portion.
    #[account(
        mut,
        constraint = fee_collector.key() == config.fee_collector,
    )]
    pub fee_collector: AccountInfo<'info>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<Donate>, amount: u64, message: String) -> Result<()> {
    require!(
        amount >= MIN_DONATION_AMOUNT,
        StreamerDonationError::BelowMinimumDonation
    );
    require!(
        message.len() <= MAX_MESSAGE_LENGTH,
        StreamerDonationError::MessageTooLong
    );

    let fee = amount
        .checked_mul(FEE_PERCENTAGE)
        .ok_or(StreamerDonationError::Overflow)?
        .checked_div(100)
        .ok_or(StreamerDonationError::Overflow)?;
    let streamer_amount = amount
        .checked_sub(fee)
        .ok_or(StreamerDonationError::Overflow)?;

    // Transfer fee to fee_collector
    if fee > 0 {
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: ctx.accounts.donor.to_account_info(),
                    to: ctx.accounts.fee_collector.to_account_info(),
                },
            ),
            fee,
        )?;
    }

    // Transfer remainder to streamer
    if streamer_amount > 0 {
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: ctx.accounts.donor.to_account_info(),
                    to: ctx.accounts.streamer_wallet.to_account_info(),
                },
            ),
            streamer_amount,
        )?;
    }

    let clock = Clock::get()?;
    let streamer_acc = &mut ctx.accounts.streamer;
    let donation_id = streamer_acc.donation_count;
    streamer_acc.donation_count = donation_id
        .checked_add(1)
        .ok_or(StreamerDonationError::Overflow)?;

    let donation = &mut ctx.accounts.donation;
    donation.donor = ctx.accounts.donor.key();
    donation.streamer = ctx.accounts.streamer_wallet.key();
    donation.amount = amount;
    donation.message = message.clone();
    donation.timestamp = clock.unix_timestamp;
    donation.donation_id = donation_id;
    donation.token_mint = Pubkey::default();
    donation.bump = ctx.bumps.donation;

    emit!(DonationReceived {
        donation_id,
        streamer: ctx.accounts.streamer_wallet.key(),
        donor: ctx.accounts.donor.key(),
        amount,
        message,
        timestamp: clock.unix_timestamp,
        token_mint: Pubkey::default(),
    });

    Ok(())
}
