use anchor_lang::prelude::*;
use anchor_spl::token_interface::{self, Mint, TokenAccount, TokenInterface, TransferChecked};
use crate::constants::*;
use crate::errors::StreamerDonationError;
use crate::events::DonationReceived;
use crate::state::{Config, Donation, Streamer};

#[derive(Accounts)]
pub struct DonateWithToken<'info> {
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

    /// CHECK: Validated via streamer PDA seeds; the streamer's wallet.
    #[account(
        constraint = streamer_wallet.key() == streamer.wallet,
    )]
    pub streamer_wallet: AccountInfo<'info>,

    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        mut,
        token::mint = mint,
        token::authority = donor,
    )]
    pub donor_token_account: InterfaceAccount<'info, TokenAccount>,

    #[account(
        mut,
        token::mint = mint,
    )]
    pub streamer_token_account: InterfaceAccount<'info, TokenAccount>,

    #[account(
        mut,
        token::mint = mint,
    )]
    pub fee_collector_token_account: InterfaceAccount<'info, TokenAccount>,

    /// CHECK: Validated against config; the fee collector wallet.
    #[account(
        constraint = fee_collector.key() == config.fee_collector,
    )]
    pub fee_collector: AccountInfo<'info>,

    pub token_program: Interface<'info, TokenInterface>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<DonateWithToken>, amount: u64, message: String) -> Result<()> {
    require!(
        amount >= MIN_SPL_DONATION_AMOUNT,
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

    let decimals = ctx.accounts.mint.decimals;

    // Transfer fee to fee_collector ATA
    if fee > 0 {
        token_interface::transfer_checked(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                TransferChecked {
                    from: ctx.accounts.donor_token_account.to_account_info(),
                    mint: ctx.accounts.mint.to_account_info(),
                    to: ctx.accounts.fee_collector_token_account.to_account_info(),
                    authority: ctx.accounts.donor.to_account_info(),
                },
            ),
            fee,
            decimals,
        )?;
    }

    // Transfer remainder to streamer ATA
    if streamer_amount > 0 {
        token_interface::transfer_checked(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                TransferChecked {
                    from: ctx.accounts.donor_token_account.to_account_info(),
                    mint: ctx.accounts.mint.to_account_info(),
                    to: ctx.accounts.streamer_token_account.to_account_info(),
                    authority: ctx.accounts.donor.to_account_info(),
                },
            ),
            streamer_amount,
            decimals,
        )?;
    }

    let clock = Clock::get()?;
    let mint_key = ctx.accounts.mint.key();
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
    donation.token_mint = mint_key;
    donation.bump = ctx.bumps.donation;

    emit!(DonationReceived {
        donation_id,
        streamer: ctx.accounts.streamer_wallet.key(),
        donor: ctx.accounts.donor.key(),
        amount,
        message,
        timestamp: clock.unix_timestamp,
        token_mint: mint_key,
    });

    Ok(())
}
