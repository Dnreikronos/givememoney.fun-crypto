use anchor_lang::prelude::*;

#[error_code]
pub enum StreamerDonationError {
    #[msg("Donation amount is below the minimum required")]
    BelowMinimumDonation,
    #[msg("Message exceeds maximum length of 280 characters")]
    MessageTooLong,
    #[msg("Program is currently paused")]
    Paused,
    #[msg("Program is not paused")]
    NotPaused,
    #[msg("Arithmetic overflow")]
    Overflow,
    #[msg("Unauthorized: caller is not the authority")]
    Unauthorized,
}
