use anchor_lang::prelude::*;
use crate::errors::StreamerDonationError;
use crate::state::Config;

#[derive(Accounts)]
pub struct Unpause<'info> {
    #[account(
        mut,
        seeds = [b"config"],
        bump = config.bump,
        has_one = authority @ StreamerDonationError::Unauthorized,
    )]
    pub config: Account<'info, Config>,

    pub authority: Signer<'info>,
}

pub fn handler(ctx: Context<Unpause>) -> Result<()> {
    require!(ctx.accounts.config.paused, StreamerDonationError::NotPaused);
    ctx.accounts.config.paused = false;
    Ok(())
}
