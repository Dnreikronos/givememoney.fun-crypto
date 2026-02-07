use anchor_lang::prelude::*;

declare_id!("FMrnRTKyLZPFK5BgZB7aGA95RVa3pVyvCtbR8oMov2n9");

#[program]
pub mod solana {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
