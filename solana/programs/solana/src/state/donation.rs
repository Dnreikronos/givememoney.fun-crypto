use anchor_lang::prelude::*;

#[account]
#[derive(InitSpace)]
pub struct Donation {
    pub donor: Pubkey,
    pub streamer: Pubkey,
    pub amount: u64,
    #[max_len(280)]
    pub message: String,
    pub timestamp: i64,
    pub donation_id: u64,
    pub token_mint: Pubkey,
    pub bump: u8,
}
