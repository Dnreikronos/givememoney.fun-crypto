use anchor_lang::prelude::*;

pub mod constants;
pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("FMrnRTKyLZPFK5BgZB7aGA95RVa3pVyvCtbR8oMov2n9");

#[program]
pub mod solana {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        instructions::initialize::handler(ctx)
    }

    pub fn register_streamer(ctx: Context<RegisterStreamer>) -> Result<()> {
        instructions::register_streamer::handler(ctx)
    }

    pub fn donate(ctx: Context<Donate>, amount: u64, message: String) -> Result<()> {
        instructions::donate::handler(ctx, amount, message)
    }

    pub fn donate_with_token(
        ctx: Context<DonateWithToken>,
        amount: u64,
        message: String,
    ) -> Result<()> {
        instructions::donate_with_token::handler(ctx, amount, message)
    }

    pub fn pause(ctx: Context<Pause>) -> Result<()> {
        instructions::pause::handler(ctx)
    }

    pub fn unpause(ctx: Context<Unpause>) -> Result<()> {
        instructions::unpause::handler(ctx)
    }
}
