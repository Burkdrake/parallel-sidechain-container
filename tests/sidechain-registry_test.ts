import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure sidechain registration works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const sidechainId = 'sidechain-test-001';
        const sidechainName = 'Test Sidechain Network';
        const networkType = 'ethereum';
        const consensusMechanism = 'proof-of-stake';
        const metadataUri = 'https://example.com/test-sidechain';

        const block = chain.mineBlock([
            Tx.contractCall(
                'sidechain-registry', 
                'register-sidechain', 
                [
                    types.ascii(sidechainId),
                    types.utf8(sidechainName),
                    types.ascii(networkType),
                    types.ascii(consensusMechanism),
                    types.some(types.utf8(metadataUri))
                ],
                deployer.address
            )
        ]);

        // First, assert transaction was successful
        block.receipts[0].result.expectOk().expectBool(true);

        // Now retrieve the sidechain and verify details
        const getSidechainCall = await chain.routers.default.call(
            'sidechain-registry', 
            'get-sidechain', 
            [types.ascii(sidechainId)]
        );

        getSidechainCall.result.expectSome();
        const sidechainDetails = getSidechainCall.result.expectSome();
        
        // Validate sidechain details
        assertEquals(sidechainDetails.name, sidechainName);
        assertEquals(sidechainDetails.owner, deployer.address);
        assertEquals(sidechainDetails.networkType, networkType);
        assertEquals(sidechainDetails.consensusMechanism, consensusMechanism);
        assertEquals(sidechainDetails.status, 0);  // Initially PENDING
        assertEquals(sidechainDetails.metadataUri, metadataUri);
    }
});

Clarinet.test({
    name: "Prevent duplicate sidechain registration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const sidechainId = 'sidechain-duplicate';
        const sidechainName = 'Duplicate Network';
        const networkType = 'bitcoin';
        const consensusMechanism = 'proof-of-work';

        const block = chain.mineBlock([
            Tx.contractCall(
                'sidechain-registry', 
                'register-sidechain', 
                [
                    types.ascii(sidechainId),
                    types.utf8(sidechainName),
                    types.ascii(networkType),
                    types.ascii(consensusMechanism),
                    types.none()
                ],
                deployer.address
            ),
            Tx.contractCall(
                'sidechain-registry', 
                'register-sidechain', 
                [
                    types.ascii(sidechainId),
                    types.utf8(sidechainName),
                    types.ascii(networkType),
                    types.ascii(consensusMechanism),
                    types.none()
                ],
                deployer.address
            )
        ]);

        // First registration should succeed
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Second registration should fail
        block.receipts[1].result.expectErr().expectUint(102);  // ERR-ALREADY-EXISTS
    }
});

Clarinet.test({
    name: "Test sidechain status update",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const sidechainId = 'sidechain-status-test';
        const sidechainName = 'Status Test Network';
        const networkType = 'solana';
        const consensusMechanism = 'proof-of-history';

        const block = chain.mineBlock([
            // First, register the sidechain
            Tx.contractCall(
                'sidechain-registry', 
                'register-sidechain', 
                [
                    types.ascii(sidechainId),
                    types.utf8(sidechainName),
                    types.ascii(networkType),
                    types.ascii(consensusMechanism),
                    types.none()
                ],
                deployer.address
            ),
            // Then update its status to ACTIVE
            Tx.contractCall(
                'sidechain-registry', 
                'update-sidechain-status', 
                [
                    types.ascii(sidechainId),
                    types.uint(1)  // STATUS-ACTIVE
                ],
                deployer.address
            )
        ]);

        // Registration should succeed
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Status update should succeed
        block.receipts[1].result.expectOk().expectBool(true);

        // Verify the sidechain is now active
        const isActiveCall = await chain.routers.default.call(
            'sidechain-registry', 
            'is-sidechain-active', 
            [types.ascii(sidechainId)]
        );

        isActiveCall.result.expectBool(true);
    }
});