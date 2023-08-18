# Peer Audit: *DAO*

### by anirudhnkl, for sunbreather

## **[M-1]** `execute()` function does not verify given targets, values, and calldatas

```
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

On lines 284-404, the `execute()` function does not check if the given targets, values, and the calldatas are the same ones
that were passed during the proposal creation. This means that the proposal executor can change the targets, values, and calldatas
after the proposal has been created and the proposal will still execute. This is a security vulnerability since the proposal executor
can do whatever they want to do with the DAO.

Consder: Hashing the targets, values, and calldatas during the proposal creation and then checking if the given targets, values, and calldatas produce the same hash as the one stored during the proposal creation.

```
function execute(
        uint256 _proposalId,
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _calldatas
    ) external {
        if(proposals[_proposalId].datahash != keccak256(abi.encodePacked(_targets, _values, _calldatas))) revert ProposalDataMismatch();
        // ... do the rest of the execution
    }
```

## **[Q-2]** `execute()` function has empty `if(success_)` block

```
if(success_) {

        }
```

On line 209, the `execute()` function has an empty `if(success_)` block. This is unnecessary and can be removed.

## **[Q-3]** unnecessary `voteStart`

```
uint256 voteStart;
```

On line 63, `voteStart` is declared but it is unnecessary and can be removed. `voteEnd` is all that is needed.

## **[Q-4]** `proposalPassed()` function does not check if the proposal has been executed

```
require(msg.sender == address(this));
```

On line 323, require is used to check if the caller is the DAO itself. A customer error should be used with revert instead of require.

# Nitpick

1. Events should have indexed parameters
