use anchor_lang::prelude::*;
use crate::errors::StreamerDonationError;
use crate::state::Config;

#[derive(Accounts)]
pub struct Pause<'info> {
    #[account(
        mut,
        seeds = [b"config"],
        bump = config.bump,
        has_one = authority @ StreamerDonationError::Unauthorized,
    )]
    pub config: Account<'info, Config>,

    pub authority: Signer<'info>,
}

pub fn handler(ctx: Context<Pause>) -> Result<()> {
    require!(!ctx.accounts.config.paused, StreamerDonationError::Paused);
    ctx.accounts.config.paused = true;
    Ok(())
}
