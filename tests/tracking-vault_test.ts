import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "tracking-vault: Asset Management Test Suite",
  
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;

    // Test asset details update
    let block = chain.mineBlock([
      Tx.contractCall('tracking-vault', 'update-asset-details', [
        types.uint(1),
        types.ascii('Updated Test Asset'),
        types.uint(500),
        types.ascii('Excellent'),
        types.some(types.utf8('https://example.com/asset1'))
      ], wallet1.address)
    ]);

    // Test asset verification
    block = chain.mineBlock([
      Tx.contractCall('tracking-vault', 'add-asset-verification', [
        types.uint(1),
        types.ascii('Insurance'),
        types.utf8('Verified for insurance coverage'),
        types.some(types.utf8('https://insurance.com/cert'))
      ], wallet2.address)
    ]);

    // Test asset deactivation
    block = chain.mineBlock([
      Tx.contractCall('tracking-vault', 'deactivate-asset', [
        types.uint(1),
        types.ascii('Asset temporarily unavailable')
      ], wallet1.address)
    ]);

    // Test asset reactivation
    block = chain.mineBlock([
      Tx.contractCall('tracking-vault', 'reactivate-asset', [
        types.uint(1),
        types.ascii('Asset restored')
      ], wallet1.address)
    ]);
  }
});