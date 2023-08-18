# DAO Project

## Technical Spec

- Allows anyone to buy a membership for 1 ETH.

- Allows a member to create governance proposals, which include a series of proposed arbitrary functions to execute.

- Allows members to vote on proposals:
    - Members can vote over 7 day period, beginning immediately after the proposal is generated.
    - A vote is either "Yes" or "No" (no “Abstain” votes).
    - A member's vote on a proposal cannot be changed after it is cast.

- A proposal is considered passed when all of the following are true:
    - The voting period has concluded.
    - There are more Yes votes than No votes.
    - A 25% quorum requirement is met.

- Allows any address to execute successfully passed proposals.

- Reverts currently executing proposals if any of the proposed arbitrary function calls fail. (Entire transaction should revert.)

- Incentivizes positive interactions with the DAO's proposals, by:
    - Incentivizing rapid execution of successfully passed proposals by offering a 0.01 ETH execution reward, provided by the DAO contract, to the address that executes the proposal.

- A standardized NFT-buying function called buyNFTFromMarketplace should exist on the DAO contract so that DAO members can include it as one of the proposed arbitrary function calls on routine NFT purchase proposals.

- Even though this DAO has one main purpose (collecting NFTs), the proposal system should support proposing the execution of any arbitrarily defined functions on any contract.

- A function that allows an individual member to vote on a specific proposal should exist on the DAO contract.

- A function that allows any address to submit a DAO member's vote using off-chain generated EIP-712 signatures should exist on the DAO contract.
    - Another function should exist that enables bulk submission and processing of many EIP-712 signature votes, from several DAO members, across multiple proposals, to be processed in a single function call.

- It should be possible to submit proposals with identical sets of proposed function calls.

- The proposal's data should not be stored in the contract's storage. Instead, only a hash of the data should be stored on-chain.

- DAO members must have joined before a proposal is created in order to be allowed to vote on that proposal.
    - Note: This applies even when the two transactions - member joining and proposal creation - fall in the same block. In that case, the ordering of transactions in the block is what matters.

- A DAO member's voting power should be increased each time they perform one of the following actions:
   - +1 voting power (from zero) when an address purchases their DAO membership
   - +1 voting power to the creator of a successfully executed proposal

## Code Coverage Report

| File                           | % Lines        | % Statements     | % Branches     | % Funcs         |
|--------------------------------|----------------|------------------|----------------|-----------------|
| script/Counter.s.sol           | 0.00% (0/1)    | 0.00% (0/1)      | 100.00% (0/0)  | 0.00% (0/2)     |
| src/contracts/CollectorDAO.sol | 97.33% (73/75) | 97.06% (99/102)  | 89.29% (50/56) | 100.00% (11/11) |
| test/MockNftMarketplace.sol    | 66.67% (6/9)   | 66.67% (6/9)     | 50.00% (3/6)   | 100.00% (2/2)   |
| Total                          | 92.94% (79/85) | 93.75% (105/112) | 85.48% (53/62) | 86.67% (13/15)  |

## Design Exercise Answer

<!-- Answer the Design Exercise. -->
<!-- In your answer: (1) Consider the tradeoffs of your design, and (2) provide some pseudocode, or a diagram, to illustrate how one would get started. -->

> Per project specs there is no vote delegation; it's not possible for Alice to delegate her voting power to Bob, so that when Bob votes he does so with the voting power of both himself and Alice in a single transaction. This means for someone's vote to count, that person must sign and broadcast their own transaction every time. How would you design your contract to allow for non-transitive vote delegation?

> What are some problems with implementing transitive vote delegation on-chain? (Transitive means: If A delegates to B, and B delegates to C, then C gains voting power from both A and B, while B has no voting power).

- My struct
```    struct Member {
        uint256 id;
        uint256 votingPower;
        // proposal id to amount
        mapping(uint256 => uint256) amountDelegated;
        mapping(uint256 => uint256) delegationReceived;
    }
```
could include the two additional fields of amountDelegated and delegationReceived. Then a function could be run to compare 
and delegate.
```        
// check signatures before calling this function
function delegateVotes(from, to, proposalId) internal {
    if(member[from].amountDelegated[proposalId] == member[from].votingPower) revert NoMoreDelegationAllowed
    // perform other checks
    member[from].amountDelegated[proposalId] = member[from].votingPower;
    member[to].delegationReceived[proposalId] += member[from].votingPower;

    // call voting function
    
}
```
The trade off of this approach is that you can only go from user A -> B. This could be enhanced to take an array so that A -> B -> C

- Some problems with transitive vote delegation on chain is that there could be unwanted situations where a majority of members all decide to delegate to a single address to amass power