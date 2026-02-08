use anchor_lang::prelude::*;
use crate::state::Streamer;
use crate::events::StreamerRegistered;

#[derive(Accounts)]
pub struct RegisterStreamer<'info> {
    #[account(
        init,
        payer = streamer_wallet,
        space = 8 + Streamer::INIT_SPACE,
        seeds = [b"streamer", streamer_wallet.key().as_ref()],
        bump,
    )]
    pub streamer: Account<'info, Streamer>,

    #[account(mut)]
    pub streamer_wallet: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<RegisterStreamer>) -> Result<()> {
    let streamer = &mut ctx.accounts.streamer;
    streamer.wallet = ctx.accounts.streamer_wallet.key();
    streamer.donation_count = 0;
    streamer.bump = ctx.bumps.streamer;

    emit!(StreamerRegistered {
        streamer: ctx.accounts.streamer_wallet.key(),
    });

    Ok(())
}
