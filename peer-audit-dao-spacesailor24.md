## CollectorDAO

- [High](#high)
  - [\[H-1\] `Line 284 - 303`: Any values can be provided for `_targets`, `_values`, and `_calldatas` when executing a passed proposal](#h-1-line-284---303-any-values-can-be-provided-for-_targets-_values-and-_calldatas-when-executing-a-passed-proposal)
    - [The Code](#the-code)
    - [A Solution](#a-solution)
- [Low](#low)
  - [\[L-1\] `Line 129, 194, and 290`: Proposal not considered ended if `block.timestamp == proposal.voteEnd`](#l-1-line-129-194-and-290-proposal-not-considered-ended-if-blocktimestamp--proposalvoteend)
    - [The corrected usage:](#the-corrected-usage)
  - [\[L-2\] `Line 293`: Proposer's voting power increased before successful execution of a proposal](#l-2-line-293-proposers-voting-power-increased-before-successful-execution-of-a-proposal)
    - [A solution](#a-solution-1)
- [Technical Mistakes](#technical-mistakes)
  - [\[TM-1\] `Line 95 & 96`: Incorrect values used for EIP-712 Domain TypeHash](#tm-1-line-95--96-incorrect-values-used-for-eip-712-domain-typehash)
    - [The corrected usage](#the-corrected-usage-1)
- [NitPicks](#nitpicks)
  - [\[NP-1\] `Line 299 - 301`: Empty if statement](#np-1-line-299---301-empty-if-statement)
    - [The correct usage](#the-correct-usage)
  - [\[NP-2\] `Line 323`: Replace usage of `require` with custom error](#np-2-line-323-replace-usage-of-require-with-custom-error)
    - [The corrected usage](#the-corrected-usage-2)
  - [\[NP-3\] `Line 20`: `Proposal.voteStart` is unnecessary](#np-3-line-20-proposalvotestart-is-unnecessary)


## High

### [H-1] `Line 284 - 303`: Any values can be provided for `_targets`, `_values`, and `_calldatas` when executing a passed proposal

There is no check that the provided  `_targets`, `_values`, and `_calldatas` arguments match the original values that were provided when a proposal was proposed. Meaning any data can be provided for these values regardless of what was originally provided

#### The Code

```solidity
function execute(
	uint256 _proposalId,
	address[] calldata _targets,
	uint256[] calldata _values,
	bytes[] calldata _calldatas
) external {
	if (!proposalPassed(_proposalId)) revert ProposalNotPassed();
	if (proposals[_proposalId].executed == true) revert ProposalAlreadyExecuted();  
	proposals[_proposalId].executed = true;
	members[proposals[_proposalId].creator].votingPower++;
	for (uint256 i = 0; i < _targets.length; i++) {
		(bool success,) = _targets[i].call{value: _values[i]}(_calldatas[i]);
		if (!success) revert ExecutionFailed();
	}
	(bool success_,) = msg.sender.call{value: EXECUTION_REWARD}("");
	if(success_) {

	}
	emit ProposalExecuted(_proposalId);
}
```

#### A Solution

One possible solution for this is to hash the provided `_targets`, `_values`, and `_calldatas` arguments provided to `propose` (`Line 157 - 185`) and store it on the `struct Proposal`, so that the hash of the original proposed values can be compared to the hashed arguments provided to `execute` function:

```solidity
function propose(
	address[] calldata _targets,
	uint256[] calldata _values,
	bytes[] calldata _calldatas,
	string calldata _description
) external onlyMember returns (uint256) {
	uint256 proposalId = proposalNonce;
	Proposal storage proposal = proposals[proposalId];
	if (_targets.length == 0) revert EmptyProposal();
	if (_targets.length != _values.length) revert InvalidProposalLength();
	if (_targets.length != _calldatas.length) revert InvalidProposalLength();

	// By including proposalId we ensure that each proposalHash is unqiue
	// even if the same _targets, _values, and _calldatas are provided
	proposal.proposalHash = keccak256(abi.encode(proposalId, _targets, _values, _calldatas));

	// ...
}

function execute(
	uint256 _proposalId,
	address[] calldata _targets,
	uint256[] calldata _values,
	bytes[] calldata _calldatas
) external {
	if (!proposalPassed(_proposalId)) revert ProposalNotPassed();
	if (proposals[_proposalId].executed == true) revert ProposalAlreadyExecuted();

	if (
		keccak256(abi.encode(_proposalId, _targets, _values, _calldatas)) !=
		proposals[_proposalId].proposalHash
	) revert IncorrectProposalValues();
	
	// ...
}
```

## Low

### [L-1] `Line 129, 194, and 290`: Proposal not considered ended if `block.timestamp == proposal.voteEnd`

On `Line 129`, `>` is used instead of `>=` to check: `block.timestamp > proposal.voteEnd`

- For `Line 194`, this means a vote can still be made if `block.timestamp == proposal.voteEnd`
- For `Line 290`, this means a should-be passed proposal cannot be executed if `block.timestamp == proposal.voteEnd`

Consider using `>=` instead of `>`

#### The corrected usage:

```solidity
if (block.timestamp >= proposal.voteEnd) revert VotingHasEnded();
```

### [L-2] `Line 293`: Proposer's voting power increased before successful execution of a proposal

The spec mentions increasing a proposer's voting power _after_ the successful execution of a proposal:

> +1 voting power to the creator of a successfully executed proposal

Because the executing proposal's proposer's voting power is increased before `Line 294 - 297` are done executing, one of the proposal's function could make use of the increased voting power before they technically should be able to

#### A solution 

Move `Line 293` to after `Line 297`

## Technical Mistakes

### [TM-1] `Line 95 & 96`: Incorrect values used for EIP-712 Domain TypeHash

The constants, `APP_NAME` and `VERSION`, are the hashes of the EIP-712 `name` and `version` when they should be the raw `string` values according to the [domainSeparator](https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator) section of EIP-712

#### The corrected usage

```solidity
string constant public APP_NAME = "CollectorDAO";
string constant public VERSION = "1";
```

## NitPicks

### [NP-1] `Line 299 - 301`: Empty if statement

Because the spec says the successful sending of funds to the proposal executor is irrelevant to the success of the proposal execution, the storage of `bool success` on `Line 298` is not necessary and the if statement preceding it can be removed

#### The correct usage

```solidity
msg.sender.call{value: EXECUTION_REWARD}("");
```

### [NP-2] `Line 323`: Replace usage of `require` with custom error

This is suggested not only to save gas, but because it provides context to the transaction sender on why their transaction was reverted


#### The corrected usage

```solidity
if (msg.sender != address(this)) revert OnlyCallableByTheDao();
```

### [NP-3] `Line 20`: `Proposal.voteStart` is unnecessary

This value is only ever used functionally on `Line 169, 193, and 244` to check whether a proposal is valid. The same could be accomplished by checking `proposal.voteEnd == 0` and some gas can be saved by not storing this variable for each proposal

Consider removing `Proposal.voteStart`