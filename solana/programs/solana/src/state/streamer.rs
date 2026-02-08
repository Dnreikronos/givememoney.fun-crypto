use anchor_lang::prelude::*;

#[account]
#[derive(InitSpace)]
pub struct Streamer {
    pub wallet: Pubkey,
    pub donation_count: u64,
    pub bump: u8,
}
