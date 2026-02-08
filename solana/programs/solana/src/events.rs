use anchor_lang::prelude::*;

#[event]
pub struct DonationReceived {
    pub donation_id: u64,
    pub streamer: Pubkey,
    pub donor: Pubkey,
    pub amount: u64,
    pub message: String,
    pub timestamp: i64,
    pub token_mint: Pubkey,
}

#[event]
pub struct StreamerRegistered {
    pub streamer: Pubkey,
}
