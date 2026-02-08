import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Solana } from "../target/types/solana";
import {
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
  SystemProgram,
} from "@solana/web3.js";
import {
  createMint,
  createAccount,
  mintTo,
  getAccount,
  TOKEN_PROGRAM_ID,
} from "@solana/spl-token";
import { expect } from "chai";
import BN from "bn.js";

describe("StreamerDonations", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.solana as Program<Solana>;
  const authority = provider.wallet as anchor.Wallet;

  // Derived PDAs
  const [configPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    program.programId
  );

  // Helpers
  const getStreamerPda = (wallet: PublicKey) =>
    PublicKey.findProgramAddressSync(
      [Buffer.from("streamer"), wallet.toBuffer()],
      program.programId
    )[0];

  const getDonationPda = (streamerWallet: PublicKey, donationId: number) =>
    PublicKey.findProgramAddressSync(
      [
        Buffer.from("donation"),
        streamerWallet.toBuffer(),
        new BN(donationId).toArrayLike(Buffer, "le", 8),
      ],
      program.programId
    )[0];

  const airdrop = async (pubkey: PublicKey, sol: number) => {
    const sig = await provider.connection.requestAirdrop(
      pubkey,
      sol * LAMPORTS_PER_SOL
    );
    await provider.connection.confirmTransaction(sig, "confirmed");
  };

  const MIN_DONATION = 1_000_000; // 0.001 SOL
  const MIN_SPL_DONATION = 1_000_000;

  // ──────────────────────────────────────────────
  // Initialize
  // ──────────────────────────────────────────────
  describe("initialize", () => {
    it("creates the config PDA", async () => {
      await program.methods
        .initialize()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();

      const config = await program.account.config.fetch(configPda);
      expect(config.authority.toBase58()).to.equal(
        authority.publicKey.toBase58()
      );
      expect(config.feeCollector.toBase58()).to.equal(
        authority.publicKey.toBase58()
      );
      expect(config.paused).to.equal(false);
    });

    it("fails on double initialization", async () => {
      try {
        await program.methods
          .initialize()
          .accounts({
            authority: authority.publicKey,
          })
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        // Account already exists — Anchor returns a SendTransactionError
        expect(err).to.exist;
      }
    });
  });

  // ──────────────────────────────────────────────
  // Register Streamer
  // ──────────────────────────────────────────────
  describe("register_streamer", () => {
    const streamerKp = Keypair.generate();

    before(async () => {
      await airdrop(streamerKp.publicKey, 2);
    });

    it("registers a new streamer", async () => {
      await program.methods
        .registerStreamer()
        .accounts({
          streamerWallet: streamerKp.publicKey,
        })
        .signers([streamerKp])
        .rpc();

      const streamer = await program.account.streamer.fetch(
        getStreamerPda(streamerKp.publicKey)
      );
      expect(streamer.wallet.toBase58()).to.equal(
        streamerKp.publicKey.toBase58()
      );
      expect(streamer.donationCount.toNumber()).to.equal(0);
    });

    it("fails when already registered", async () => {
      try {
        await program.methods
          .registerStreamer()
          .accounts({
            streamerWallet: streamerKp.publicKey,
          })
          .signers([streamerKp])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err).to.exist;
      }
    });
  });

  // ──────────────────────────────────────────────
  // Donate SOL
  // ──────────────────────────────────────────────
  describe("donate (SOL)", () => {
    const streamerKp = Keypair.generate();
    const donorKp = Keypair.generate();

    before(async () => {
      await airdrop(streamerKp.publicKey, 2);
      await airdrop(donorKp.publicKey, 10);

      // Register streamer
      await program.methods
        .registerStreamer()
        .accounts({
          streamerWallet: streamerKp.publicKey,
        })
        .signers([streamerKp])
        .rpc();
    });

    it("donates SOL with correct 95/5 split", async () => {
      const amount = 1_000_000_000; // 1 SOL
      const fee = (amount * 5) / 100;
      const streamerAmount = amount - fee;

      const streamerBalBefore = await provider.connection.getBalance(
        streamerKp.publicKey
      );
      const feeCollectorBalBefore = await provider.connection.getBalance(
        authority.publicKey
      );

      await program.methods
        .donate(new BN(amount), "Hello streamer!")
        .accounts({
          donor: donorKp.publicKey,
          streamerWallet: streamerKp.publicKey,
          feeCollector: authority.publicKey,
        })
        .signers([donorKp])
        .rpc();

      const streamerBalAfter = await provider.connection.getBalance(
        streamerKp.publicKey
      );
      const feeCollectorBalAfter = await provider.connection.getBalance(
        authority.publicKey
      );

      expect(streamerBalAfter - streamerBalBefore).to.equal(streamerAmount);
      // Authority is both fee_collector and tx fee payer; verify the fee
      // collector received at least the platform fee minus the tx cost
      const feeCollectorDelta = feeCollectorBalAfter - feeCollectorBalBefore;
      expect(feeCollectorDelta).to.be.greaterThan(0);
      expect(feeCollectorDelta).to.be.lessThanOrEqual(fee);

      // Verify on-chain donation record
      const donationPda = getDonationPda(streamerKp.publicKey, 0);
      const donation = await program.account.donation.fetch(donationPda);
      expect(donation.donor.toBase58()).to.equal(donorKp.publicKey.toBase58());
      expect(donation.streamer.toBase58()).to.equal(
        streamerKp.publicKey.toBase58()
      );
      expect(donation.amount.toNumber()).to.equal(amount);
      expect(donation.message).to.equal("Hello streamer!");
      expect(donation.donationId.toNumber()).to.equal(0);
      expect(donation.tokenMint.toBase58()).to.equal(
        PublicKey.default.toBase58()
      );

      // Verify streamer donation_count incremented
      const streamer = await program.account.streamer.fetch(
        getStreamerPda(streamerKp.publicKey)
      );
      expect(streamer.donationCount.toNumber()).to.equal(1);
    });

    it("increments donation IDs sequentially", async () => {
      const amount = MIN_DONATION;

      await program.methods
        .donate(new BN(amount), "Second donation")
        .accounts({
          donor: donorKp.publicKey,
          streamerWallet: streamerKp.publicKey,
          feeCollector: authority.publicKey,
        })
        .signers([donorKp])
        .rpc();

      const donationPda = getDonationPda(streamerKp.publicKey, 1);
      const donation = await program.account.donation.fetch(donationPda);
      expect(donation.donationId.toNumber()).to.equal(1);

      const streamer = await program.account.streamer.fetch(
        getStreamerPda(streamerKp.publicKey)
      );
      expect(streamer.donationCount.toNumber()).to.equal(2);
    });

    it("fails when amount is below minimum", async () => {
      try {
        await program.methods
          .donate(new BN(MIN_DONATION - 1), "Too small")
          .accounts({
            donor: donorKp.publicKey,
            streamerWallet: streamerKp.publicKey,
            feeCollector: authority.publicKey,
          })
          .signers([donorKp])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err.error.errorCode.code).to.equal("BelowMinimumDonation");
      }
    });

    it("fails when message is too long", async () => {
      const longMessage = "A".repeat(281);
      try {
        await program.methods
          .donate(new BN(MIN_DONATION), longMessage)
          .accounts({
            donor: donorKp.publicKey,
            streamerWallet: streamerKp.publicKey,
            feeCollector: authority.publicKey,
          })
          .signers([donorKp])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err.error.errorCode.code).to.equal("MessageTooLong");
      }
    });

    it("fails when streamer is not registered", async () => {
      const unregistered = Keypair.generate();
      try {
        await program.methods
          .donate(new BN(MIN_DONATION), "Hello")
          .accounts({
            donor: donorKp.publicKey,
            streamerWallet: unregistered.publicKey,
            feeCollector: authority.publicKey,
          })
          .signers([donorKp])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        // AccountNotInitialized — streamer PDA doesn't exist
        expect(err).to.exist;
      }
    });

    it("fails when program is paused", async () => {
      // Pause
      await program.methods
        .pause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();

      try {
        await program.methods
          .donate(new BN(MIN_DONATION), "Should fail")
          .accounts({
            donor: donorKp.publicKey,
            streamerWallet: streamerKp.publicKey,
            feeCollector: authority.publicKey,
          })
          .signers([donorKp])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err.error.errorCode.code).to.equal("Paused");
      }

      // Unpause for remaining tests
      await program.methods
        .unpause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();
    });
  });

  // ──────────────────────────────────────────────
  // Donate with Token
  // ──────────────────────────────────────────────
  describe("donate_with_token (SPL)", () => {
    const streamerKp = Keypair.generate();
    const donorKp = Keypair.generate();
    let mint: PublicKey;
    let donorAta: PublicKey;
    let streamerAta: PublicKey;
    let feeCollectorAta: PublicKey;
    const decimals = 6;

    before(async () => {
      await airdrop(streamerKp.publicKey, 2);
      await airdrop(donorKp.publicKey, 10);

      // Register streamer
      await program.methods
        .registerStreamer()
        .accounts({
          streamerWallet: streamerKp.publicKey,
        })
        .signers([streamerKp])
        .rpc();

      // Create SPL token mint (authority is the provider wallet)
      mint = await createMint(
        provider.connection,
        (authority as any).payer,
        authority.publicKey,
        null,
        decimals
      );

      // Create ATAs
      donorAta = await createAccount(
        provider.connection,
        (authority as any).payer,
        mint,
        donorKp.publicKey
      );
      streamerAta = await createAccount(
        provider.connection,
        (authority as any).payer,
        mint,
        streamerKp.publicKey
      );
      feeCollectorAta = await createAccount(
        provider.connection,
        (authority as any).payer,
        mint,
        authority.publicKey
      );

      // Mint tokens to donor
      await mintTo(
        provider.connection,
        (authority as any).payer,
        mint,
        donorAta,
        authority.publicKey,
        100_000_000 // 100 tokens
      );
    });

    it("donates SPL tokens with correct 95/5 split", async () => {
      const amount = 10_000_000; // 10 tokens
      const fee = (amount * 5) / 100;
      const streamerAmount = amount - fee;

      const streamerBefore = (
        await getAccount(provider.connection, streamerAta)
      ).amount;
      const feeBefore = (await getAccount(provider.connection, feeCollectorAta))
        .amount;

      await program.methods
        .donateWithToken(new BN(amount), "Token donation!")
        .accounts({
          donor: donorKp.publicKey,
          streamerWallet: streamerKp.publicKey,
          mint,
          donorTokenAccount: donorAta,
          streamerTokenAccount: streamerAta,
          feeCollectorTokenAccount: feeCollectorAta,
          feeCollector: authority.publicKey,
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .signers([donorKp])
        .rpc();

      const streamerAfter = (await getAccount(provider.connection, streamerAta))
        .amount;
      const feeAfter = (await getAccount(provider.connection, feeCollectorAta))
        .amount;

      expect(Number(streamerAfter - streamerBefore)).to.equal(streamerAmount);
      expect(Number(feeAfter - feeBefore)).to.equal(fee);

      // Verify donation record
      const donationPda = getDonationPda(streamerKp.publicKey, 0);
      const donation = await program.account.donation.fetch(donationPda);
      expect(donation.tokenMint.toBase58()).to.equal(mint.toBase58());
      expect(donation.amount.toNumber()).to.equal(amount);
      expect(donation.message).to.equal("Token donation!");
      expect(donation.donationId.toNumber()).to.equal(0);
    });

    it("fails when token amount is below minimum", async () => {
      try {
        await program.methods
          .donateWithToken(new BN(MIN_SPL_DONATION - 1), "Too small")
          .accounts({
            donor: donorKp.publicKey,
            streamerWallet: streamerKp.publicKey,
            mint,
            donorTokenAccount: donorAta,
            streamerTokenAccount: streamerAta,
            feeCollectorTokenAccount: feeCollectorAta,
            feeCollector: authority.publicKey,
            tokenProgram: TOKEN_PROGRAM_ID,
          })
          .signers([donorKp])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err.error.errorCode.code).to.equal("BelowMinimumDonation");
      }
    });

    it("fails when program is paused", async () => {
      await program.methods
        .pause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();

      try {
        await program.methods
          .donateWithToken(new BN(MIN_SPL_DONATION), "Paused")
          .accounts({
            donor: donorKp.publicKey,
            streamerWallet: streamerKp.publicKey,
            mint,
            donorTokenAccount: donorAta,
            streamerTokenAccount: streamerAta,
            feeCollectorTokenAccount: feeCollectorAta,
            feeCollector: authority.publicKey,
            tokenProgram: TOKEN_PROGRAM_ID,
          })
          .signers([donorKp])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err.error.errorCode.code).to.equal("Paused");
      }

      // Unpause
      await program.methods
        .unpause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();
    });

    it("stores the correct mint in the donation record", async () => {
      const amount = MIN_SPL_DONATION;

      await program.methods
        .donateWithToken(new BN(amount), "Mint check")
        .accounts({
          donor: donorKp.publicKey,
          streamerWallet: streamerKp.publicKey,
          mint,
          donorTokenAccount: donorAta,
          streamerTokenAccount: streamerAta,
          feeCollectorTokenAccount: feeCollectorAta,
          feeCollector: authority.publicKey,
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .signers([donorKp])
        .rpc();

      const donationPda = getDonationPda(streamerKp.publicKey, 1);
      const donation = await program.account.donation.fetch(donationPda);
      expect(donation.tokenMint.toBase58()).to.equal(mint.toBase58());
    });
  });

  // ──────────────────────────────────────────────
  // Pause / Unpause
  // ──────────────────────────────────────────────
  describe("pause / unpause", () => {
    it("authority can pause", async () => {
      await program.methods
        .pause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();

      const config = await program.account.config.fetch(configPda);
      expect(config.paused).to.equal(true);
    });

    it("fails to pause when already paused", async () => {
      try {
        await program.methods
          .pause()
          .accounts({
            authority: authority.publicKey,
          })
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err.error.errorCode.code).to.equal("Paused");
      }
    });

    it("authority can unpause", async () => {
      await program.methods
        .unpause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();

      const config = await program.account.config.fetch(configPda);
      expect(config.paused).to.equal(false);
    });

    it("fails to unpause when not paused", async () => {
      try {
        await program.methods
          .unpause()
          .accounts({
            authority: authority.publicKey,
          })
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err.error.errorCode.code).to.equal("NotPaused");
      }
    });

    it("non-authority cannot pause", async () => {
      const rando = Keypair.generate();
      await airdrop(rando.publicKey, 1);

      try {
        await program.methods
          .pause()
          .accounts({
            authority: rando.publicKey,
          })
          .signers([rando])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        // has_one constraint violation
        expect(err).to.exist;
      }
    });

    it("non-authority cannot unpause", async () => {
      // Pause first
      await program.methods
        .pause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();

      const rando = Keypair.generate();
      await airdrop(rando.publicKey, 1);

      try {
        await program.methods
          .unpause()
          .accounts({
            authority: rando.publicKey,
          })
          .signers([rando])
          .rpc();
        expect.fail("should have thrown");
      } catch (err: any) {
        expect(err).to.exist;
      }

      // Unpause for cleanup
      await program.methods
        .unpause()
        .accounts({
          authority: authority.publicKey,
        })
        .rpc();
    });
  });
});
