-include .env

.PHONY: all install compile anvil help

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80


# Main commands
all: clean remove install update build 

install:
	@echo "Installing libraries"
	@npm install
	@forge compile --via-ir

compile:
	@forge b --via-ir --sizes

anvil:
	@echo "Starting Anvil, remember to use another terminal to run tests"
	@anvil -m 'test test test test test test test test test test test junk' \
		--steps-tracing \
		--host 0.0.0.0 --chain-id 1337 \
		--disable-code-size-limit


deploy: 
	@forge clean
	@echo "Deploying"
	@forge script script/Deploy.s.sol:DeployScript \
		--via-ir --optimize true\
		--rpc-url http://0.0.0.0:8545 \
		--private-key $(DEFAULT_ANVIL_KEY) \
		--broadcast \
		-vvvv


# Test commands

fullTest:
	@echo "Running all tests"
	@echo "Running all EVVM unit correct tests"
	@forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all EVVM unit revert tests"
	@forge test --match-contract unitTestRevert_EVVM --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all EVVM unit fuzz tests"
	@forge test --match-contract fuzzTest_EVVM --summary --detailed --gas-report -vvv --show-progress
	@sleep 5
	@echo "Running all Staking unit correct tests"
	@forge test --match-contract unitTestCorrect_Staking --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Staking unit revert tests"
	@forge test --match-contract unitTestRevert_Staking --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Staking unit fuzz tests"
	@forge test --match-contract fuzzTest_Staking --summary --detailed --gas-report -vvv --show-progress
	@sleep 5
	@echo "Running all NameService unit correct tests"
	@forge test --match-contract unitTestCorrect_NameService --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all NameService unit revert tests"
	@forge test --match-contract unitTestRevert_NameService --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all NameService unit fuzz tests"
	@forge test --match-contract fuzzTest_NameService --summary --detailed --gas-report -vvv --show-progress
	@sleep 5
	@echo "Running all Treasury unit correct tests"
	@forge test --match-contract unitTestCorrect_Treasury --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Treasury unit revert tests"
	@forge test --match-contract unitTestRevert_Treasury --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Treasury unit fuzz tests"
	@forge test --match-contract fuzzTest_Treasury --summary --detailed --gas-report -vvv --show-progress
## EVVM

testEvvm:
	@echo "Running all EVVM unit correct tests"
	@forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all EVVM unit revert tests"
	@forge test --match-contract unitTestRevert_EVVM --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all EVVM unit fuzz tests"
	@forge test --match-contract fuzzTest_EVVM --summary --detailed --gas-report -vvv --show-progress

### Unit tests

unitTestEvvm:
	@echo "Running all EVVM unit correct tests"
	@forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress 
	@sleep 3
	@echo "Running all EVVM unit revert tests"
	@forge test --match-contract unitTestRevert_EVVM --summary --detailed --gas-report -vvv --show-progress

#### Correct Tests

unitTestCorrectEvvm:
	@echo "Running all EVVM unit correct tests"
	@forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress 

unitTestCorrectEvvmPayNoStaker_async:
	@echo "Running NoMateStaking_async unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_pay_noStaker_async.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmPayNoStaker_sync:
	@echo "Running NoMateStaking_sync unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_pay_noStaker_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmPayStaker_async:
	@echo "Running PayStaker_async unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_pay_staker_async.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmPayStaker_sync:
	@echo "Running PayStaker_sync unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_pay_staker_sync.t.sol --summary --detailed --gas-report -vvv --show-progress
	
unitTestCorrectEvvmPayMultiple:
	@echo "Running PayMultiple unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_payMultiple.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmDispersePaySync:
	@echo "Running DispersePaySync unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_dispersePay_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmDispersePayAsync:
	@echo "Running DispersePayAsync unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_dispersePay_async.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmCaPay:
	@echo "Running CaPay unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_caPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmDisperseCaPay:
	@echo "Running DisperseCaPay unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_disperseCaPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmAdminFunctions:
	@echo "Running AdminFunctions unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmProxy:
	@echo "Running EVVM proxy unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_proxy.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Revert Tests

unitTestRevertEvvm:
	@echo "Running all EVVM unit revert tests"
	@forge test --match-contract unitTestRevert_EVVM --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmPayNoStaker_sync:
	@echo "Running NoMateStaking_sync unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_pay_noStaker_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmPayNoStaker_async:
	@echo "Running NoMateStaking_async unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_pay_noStaker_async.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmPayStaker_sync:
	@echo "Running PayStaker_sync unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_pay_staker_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmPayMultiple_syncExecution:
	@echo "Running PayMultiple (sync execution) unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_payMultiple_syncExecution.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmPayMultiple_asyncExecution:
	@echo "Running PayMultiple (async execution) unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_payMultiple_asyncExecution.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmDispersePay_syncExecution:
	@echo "Running DispersePay (sync execution) unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_dispersePay_syncExecution.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmDispersePay_asyncExecution:
	@echo "Running DispersePay (async execution) unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_dispersePay_asyncExecution.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmCaPay:
	@echo "Running CaPay unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_caPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmDisperseCaPay:
	@echo "Running DisperseCaPay unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_disperseCaPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmAdminFunctions:
	@echo "Running AdminFunctions unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmProxy:
	@echo "Running EVVM proxy unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_proxy.t.sol --summary --detailed --gas-report -vvv --show-progress

### Fuzz tests

unitTestFuzzEvvm:
	@echo "Running all EVVM unit fuzz tests"
	@forge test --match-contract fuzzTest_EVVM --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPay:
	@echo "Running NoMateStaking_sync unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_pay.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayNoStaker_sync:
	@echo "Running NoMateStaking_sync unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_pay_noStaker_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayNoStaker_async:
	@echo "Running NoMateStaking_async unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_pay_noStaker_async.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayStaker_sync:
	@echo "Running PayStaker_sync unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_pay_staker_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayStaker_async:
	@echo "Running PayStaker_async unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_pay_staker_async.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayMultiple:
	@echo "Running PayMultiple unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_payMultiple.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmDispersePay:
	@echo "Running DispersePay unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_dispersePay.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmCaPay:
	@echo "Running CaPay unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_caPay.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmDisperseCaPay:
	@echo "Running DisperseCaPay unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_disperseCaPay.t.sol --summary --detailed --gas-report -vvv --show-progress

## Staking

testStaking:
	@echo "Running all Staking unit correct tests"
	@forge test --match-contract unitTestCorrect_Staking --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Staking unit revert tests"
	@forge test --match-contract unitTestRevert_Staking --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Staking unit fuzz tests"
	@forge test --match-contract fuzzTest_Staking --summary --detailed --gas-report -vvv --show-progress

### Unit tests

unitTestStaking:
	@echo "Running all Staking unit correct tests"
	@forge test --match-contract unitTestCorrect_Staking --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Staking unit revert tests"
	@forge test --match-contract unitTestRevert_Staking --summary --detailed --gas-report -vvv --show-progress

#### Correct Tests

unitTestCorrectStaking:
	@echo "Running all Staking unit correct tests"
	@forge test --match-contract unitTestCorrect_Staking --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingGoldenStaking:
	@echo "Running GoldenStaking unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_goldenStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingPresaleStaking_AsyncExecutionOnPay:
	@echo "Running PresaleStaking (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_presaleStaking_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingPresaleStaking_SyncExecutionOnPay:
	@echo "Running PresaleStaking (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_presaleStaking_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingPublicStaking_AsyncExecutionOnPay:
	@echo "Running PublicStaking (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_publicStaking_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingPublicStaking_SyncExecutionOnPay:
	@echo "Running PublicStaking (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_publicStaking_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingPublicServiceStaking_AsyncExecutionOnPay:
	@echo "Running PublicServiceStaking (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_publicServiceStaking_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingPublicServiceStaking_SyncExecutionOnPay:
	@echo "Running PublicServiceStaking (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_publicServiceStaking_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectStakingAdminFunctions:
	@echo "Running AdminFunctions unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_Staking_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Revert Tests

unitTestRevertStaking:
	@echo "Running all Staking unit revert tests"
	@forge test --match-contract unitTestRevert_Staking --summary --detailed --gas-report -vvv --show-progress

unitTestRevertStakingGoldenStaking:
	@echo "Running GoldenStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_Staking_goldenStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertStakingPresaleStaking:
	@echo "Running PresaleStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_Staking_presaleStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertStakingPublicStaking:
	@echo "Running PublicStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_Staking_publicStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertStakingPublicServiceStaking:
	@echo "Running PublicServiceStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_Staking_publicServiceStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertStakingAdminFunctions:
	@echo "Running AdminFunctions unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_Staking_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Fuzz Tests

fuzzTestStaking:
	@echo "Running Staking unit fuzz tests"
	@forge test --match-contract fuzzTest_Staking --summary --detailed --gas-report -vvv --show-progress

fuzzTestStakingGoldenStaking:
	@echo "Running GoldenStaking unit fuzz tests"
	@forge test --match-path test/fuzz/staking/fuzzTest_Staking_goldenStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestStakingPresaleStaking:
	@echo "Running PresaleStaking unit fuzz tests"
	@forge test --match-path test/fuzz/staking/fuzzTest_Staking_presaleStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestStakingPublicStaking:
	@echo "Running PublicStaking unit fuzz tests"
	@forge test --match-path test/fuzz/staking/fuzzTest_Staking_publicStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestStakingPublicServiceStaking:
	@echo "Running PublicServiceStaking unit fuzz tests"
	@forge test --match-path test/fuzz/staking/fuzzTest_Staking_publicServiceStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

## Estimator

### Unit tests

#### Correct Tests

unitTestCorrectEstimator:
	@echo "Running all estimator unit correct tests"
	@forge test --match-contract unitTestCorrect_Estimator --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEstimatorNotifyNewEpoch:
	@echo "Running estimator notifyNewEpoch unit correct tests"
	@forge test --match-path test/unit/estimator/correct/unitTestCorrect_Estimator_notifyNewEpoch.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEstimatorMakeEstimation:
	@echo "Running estimator makeEstimation unit correct tests"
	@forge test --match-path test/unit/estimator/correct/unitTestCorrect_Estimator_makeEstimation.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEstimatorAdminFunctions:
	@echo "Running estimator admin functions unit correct tests"
	@forge test --match-path test/unit/estimator/correct/unitTestCorrect_Estimator_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Revert Tests

unitTestRevertEstimator:
	@echo "Running all estimator unit revert tests"
	@forge test --match-contract unitTestRevert_Estimator --summary --detailed --gas-report -vvv --show-progress


## NameService

testNameService:
	@echo "Running all NameService unit correct tests"
	@forge test --match-contract unitTestCorrect_NameService --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all NameService unit revert tests"
	@forge test --match-contract unitTestRevert_NameService --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all NameService unit fuzz tests"
	@forge test --match-contract fuzzTest_NameService --summary --detailed --gas-report -vvv --show-progress

### Unit tests

unitTestNameService:
	@echo "Running all NameService unit correct tests"
	@forge test --match-contract unitTestCorrect_NameService --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all NameService unit revert tests"
	@forge test --match-contract unitTestRevert_NameService --summary --detailed --gas-report -vvv --show-progress

#### Correct Tests

unitTestCorrectNameService:
	@echo "Running all NameService unit correct tests"
	@forge test --match-contract unitTestCorrect_NameService --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServicePreRegistrationUsername_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_preRegistrationUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServicePreRegistrationUsername_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_preRegistrationUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceRegistrationUsername_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_registrationUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceRegistrationUsername_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_registrationUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceMakeOffer_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_makeOffer_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceMakeOffer_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_makeOffer_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceWithdrawOffer_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_withdrawOffer_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceWithdrawOffer_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_withdrawOffer_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceAcceptOffer_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_acceptOffer_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceAcceptOffer_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_acceptOffer_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceRenewUsername_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_renewUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceRenewUsername_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_renewUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceAddCustomMetadata_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_addCustomMetadata_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceAddCustomMetadata_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_addCustomMetadata_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceRemoveCustomMetadata_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_removeCustomMetadata_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceRemoveCustomMetadata_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_removeCustomMetadata_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceFlushCustomMetadata_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_flushCustomMetadata_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceFlushCustomMetadata_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_flushCustomMetadata_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceFlushUsername_AsyncExecutionOnPay:
	@echo "Running NameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_flushUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceFlushUsername_SyncExecutionOnPay:
	@echo "Running NameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_flushUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectNameServiceAdminFunctions:
	@echo "Running NameService unit correct tests"
	@forge test --match-path test/unit/nameService/correct/unitTestCorrect_NameService_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Revert tests

unitTestRevertNameService:
	@echo "Running NameService unit revert tests"
	@forge test --match-contract unitTestRevert_NameService --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServicePreRegistrationUsername:
	@echo "Running NameService unit revert tests"
		@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_preRegistrationUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceRegistrationUsername:
	@echo "Running NameService unit revert tests"
		@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_registrationUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceMakeOffer:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_makeOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceWithdrawOffer:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_withdrawOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceAcceptOffer:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_acceptOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceRenewUsername:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_renewUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceAddCustomMetadata:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_addCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceRemoveCustomMetadata:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_removeCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceFlushCustomMetadata:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_flushCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceFlushUsername:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_flushUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertNameServiceAdminFunctions:
	@echo "Running NameService unit revert tests"
	@forge test --match-path test/unit/nameService/revert/unitTestRevert_NameService_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Fuzz tests

fuzzTestNameServicePreRegistrationUsername:
	@echo "Running NameService fuzz tests for preRegistrationUsername"
	@forge test --match-contract fuzzTest_NameService_preRegistrationUsername --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceRegistrationUsername:
	@echo "Running NameService fuzz tests for registrationUsername"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_registrationUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceMakeOffer:
	@echo "Running NameService fuzz tests for makeOffer"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_makeOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceWithdrawOffer:
	@echo "Running NameService fuzz tests for withdrawOffer"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_withdrawOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceAcceptOffer:
	@echo "Running NameService fuzz tests for acceptOffer"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_acceptOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceRenewUsername:
	@echo "Running NameService fuzz tests for renewUsername"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_renewUsername.t.sol --summary --detailed --gas-report -vvvv --show-progress

fuzzTestNameServiceAddCustomMetadata:
	@echo "Running NameService fuzz tests for addCustomMetadata"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_addCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceRemoveCustomMetadata:
	@echo "Running NameService fuzz tests for removeCustomMetadata"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_removeCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceFlushCustomMetadata:
	@echo "Running NameService fuzz tests for flushCustomMetadata"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_flushCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestNameServiceFlushUsername:
	@echo "Running NameService fuzz tests for flushUsername"
	@forge test --match-path test/fuzz/nameService/fuzzTest_NameService_flushUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

## Treasury

testTreasury:
	@echo "Running all Treasury unit correct tests"
	@forge test --match-contract unitTestCorrect_Treasury --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Treasury unit revert tests"
	@forge test --match-contract unitTestRevert_Treasury --summary --detailed --gas-report -vvv --show-progress
	@sleep 3
	@echo "Running all Treasury unit fuzz tests"
	@forge test --match-contract fuzzTest_Treasury --summary --detailed --gas-report -vvv --show-progress

### Unit tests

#### Correct Tests

unitTestCorrectTreasury:
	@echo "Running all Treasury unit correct tests"
	@forge test --match-contract unitTestCorrect_Treasury --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectTreasuryDeposit:
	@echo "Running Treasury deposit unit correct tests"
	@forge test --match-path test/unit/treasury/correct/unitTestCorrect_Treasury_deposit.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectTreasuryWithdraw:
	@echo "Running Treasury withdraw unit correct tests"
	@forge test --match-path test/unit/treasury/correct/unitTestCorrect_Treasury_withdraw.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Revert Tests

unitTestRevertTreasury:
	@echo "Running all Treasury unit revert tests"
	@forge test --match-contract unitTestRevert_Treasury --summary --detailed --gas-report -vvv --show-progress

unitTestRevertTreasuryDeposit:
	@echo "Running Treasury deposit unit revert tests"
	@forge test --match-path test/unit/treasury/revert/unitTestRevert_Treasury_deposit.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertTreasuryWithdraw:
	@echo "Running Treasury withdraw unit revert tests"
	@forge test --match-path test/unit/treasury/revert/unitTestRevert_Treasury_withdraw.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Fuzz Tests
fuzzTestTreasury:
	@echo "Running Treasury unit fuzz tests"
	@forge test --match-contract fuzzTest_Treasury --summary --detailed --gas-report -vvv --show-progress

fuzzTestTreasuryDeposit:
	@echo "Running Treasury deposit unit fuzz tests"
	@forge test --match-path test/fuzz/treasury/fuzzTest_Treasury_deposit.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestTreasuryWithdraw:
	@echo "Running Treasury withdraw unit fuzz tests"
	@forge test --match-path test/fuzz/treasury/fuzzTest_Treasury_withdraw.t.sol --summary --detailed --gas-report -vvv --show-progress

## P2PSwap

### Unit tests

#### Correct Tests

unitTestCorrectP2PSwapMakeOrder:
	@echo "Running P2PSwap makeOrder unit correct tests"
	@forge test --match-path test/unit/p2pSwap/correct/unitTestCorrect_P2PSwap_makeOrder.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectP2PSwapCancelOrder:
	@echo "Running P2PSwap cancelOrder unit correct tests"
	@forge test --match-path test/unit/p2pSwap/correct/unitTestCorrect_P2PSwap_cancelOrder.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectP2PSwapDispatchOrderFillPropotionalFee:
	@echo "Running P2PSwap dispatchOrder_fillPropotionalFee unit correct tests"
	@forge test --match-path test/unit/p2pSwap/correct/unitTestCorrect_P2PSwap_dispatchOrder_fillPropotionalFee.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectP2PSwapDispatchOrderFillFixedFee:
	@echo "Running P2PSwap dispatchOrder_fillPropotionalFee unit correct tests"
	@forge test --match-path test/unit/p2pSwap/correct/unitTestCorrect_P2PSwap_dispatchOrder_fillFixedFee.t.sol --summary --detailed --gas-report -vvv --show-progress


######################################################################################################

# Other commands
staticAnalysis:
	@echo "Running static analysis with Wake detector to identify security vulnerabilities and code issues"
	@wake detect all >> reportWake.txt

# Help command
help:                 
	@echo ""
	@echo "=================================================================================="
	@echo ""
	@echo "-----------------------=Basic Commands=----------------------"
	@echo ""
	@echo "  make all ----------- Clean environment, install dependencies, update libraries and build all contracts"
	@echo "  make install ------- Install npm and Foundry dependencies, then compile contracts with IR optimization"
	@echo "  make compile ------- Compile contracts with IR optimization and display contract sizes"
	@echo "  make anvil --------- Start Anvil local testnet with predefined mnemonic and transaction tracing enabled"
	@echo "  make help ---------- Display this comprehensive help message with all available commands"
	@echo ""
	@echo "-----------------------=Mock Deployers (Anvil)=----------------------"
	@echo ""
	@echo "  make mock ---------- Deploy all mock contracts (MockToken, MockTreasury, and EVVM) to local Anvil network"
	@echo ""
	@echo "-----------------------=Deployment Commands=----------------------"
	@echo ""
	@echo "  make deploy -------- Deploy production contracts to configured network using DeployTestnet script"
	@echo ""
	@echo "-----------------------=Test Suite Commands=----------------------"
	@echo ""
	@echo "  # Comprehensive Test Suites"
	@echo "  make fullProtocolTest --- Execute complete test suite for all protocol components (EVVM + Staking + NameService + Estimator)"
	@echo ""
	@echo "  # EVVM Test Suite"
	@echo "  make fullTestEvvm ------- Run comprehensive EVVM test suite (unit correct + revert + fuzz tests)"
	@echo "  make testEvvm ----------- Execute all EVVM unit tests that verify correct functionality"
	@echo "  make testEvvmRevert ----- Execute all EVVM unit tests that verify proper revert conditions"
	@echo ""
	@echo "  # Staking Test Suite"
	@echo "  make fullTestStaking ------ Run comprehensive Staking staking test suite (unit correct + revert + fuzz tests)"
	@echo "  make testStaking ---------- Execute all Staking unit tests that verify correct staking functionality"
	@echo "  make testStakingRevert ---- Execute all Staking unit tests that verify proper revert conditions"
	@echo ""
	@echo "  # NameService (NameService) Test Suite"
	@echo "  make fullTestNameService -------- Run comprehensive NameService test suite (unit correct + revert + fuzz tests)"
	@echo "  make testNameService ------------ Execute all NameService unit tests that verify correct name service functionality"
	@echo "  make testNameServiceRevert ------ Execute all NameService unit tests that verify proper revert conditions"
	@echo ""
	@echo "  # Estimator Test Suite"
	@echo "  make testEstimator ------ Execute all estimator tests for gas estimation and epoch management"
	@echo ""
	@echo "-----------------------=Individual EVVM Tests=----------------------"
	@echo ""
	@echo "  # Unit Correct Tests - Verify Expected Behavior"
	@echo "  make unitTestCorrectEvvm ------------------------- Run all EVVM unit tests for correct functionality"
	@echo "  make unitTestCorrectEvvmPayNoStaker_async --- Test async payments without mate staking requirements"
	@echo "  make unitTestCorrectEvvmPayNoStaker_sync ---- Test sync payments without mate staking requirements"
	@echo "  make unitTestCorrectEvvmPayStaker_async ----- Test async payments with mate staking integration"
	@echo "  make unitTestCorrectEvvmPayStaker_sync ------ Test sync payments with mate staking integration"
	@echo "  make unitTestCorrectEvvmPayMultiple -------------- Test batch payment functionality to multiple recipients"
	@echo "  make unitTestCorrectEvvmDispersePaySync ---------- Test synchronous payment dispersion mechanisms"
	@echo "  make unitTestCorrectEvvmDispersePayAsync --------- Test asynchronous payment dispersion mechanisms"
	@echo "  make unitTestCorrectEvvmCaPay -------------------- Test CA (Contract Account) payment functionality"
	@echo "  make unitTestCorrectEvvmDisperseCaPay ------------ Test CA payment dispersion to multiple contracts"
	@echo "  make unitTestCorrectEvvmAdminFunctions ----------- Test administrative functions (access control, configuration)"
	@echo "  make unitTestCorrectEvvmProxy -------------------- Test proxy contract functionality and upgrades"
	@echo ""
	@echo "  # Unit Revert Tests - Verify Error Conditions"
	@echo "  make unitTestRevertEvvm -------------------------- Run all EVVM revert tests for error handling"
	@echo "  make unitTestRevertEvvmPayNoStaker_sync ----- Test revert conditions for sync payments without staking"
	@echo "  make unitTestRevertEvvmPayNoStaker_async ---- Test revert conditions for async payments without staking"
	@echo "  make unitTestRevertEvvmPayStaker_sync ------- Test revert conditions for sync payments with staking"
	@echo "  make unitTestRevertEvvmPayMultiple_syncExecution - Test revert conditions for sync batch payments"
	@echo "  make unitTestRevertEvvmPayMultiple_asyncExecution  Test revert conditions for async batch payments"
	@echo "  make unitTestRevertEvvmDispersePay_syncExecution - Test revert conditions for sync payment dispersion"
	@echo "  make unitTestRevertEvvmDispersePay_asyncExecution  Test revert conditions for async payment dispersion"
	@echo "  make unitTestRevertEvvmCaPay --------------------- Test revert conditions for CA payments"
	@echo "  make unitTestRevertEvvmDisperseCaPay ------------- Test revert conditions for CA payment dispersion"
	@echo "  make unitTestRevertEvvmAdminFunctions ------------ Test revert conditions for unauthorized admin access"
	@echo "  make unitTestRevertEvvmProxy --------------------- Test revert conditions for proxy operations"
	@echo ""
	@echo "  # Fuzz Tests - Property-Based Testing with Random Inputs"
	@echo "  make unitTestFuzzEvvm ---------------------------- Run all EVVM fuzz tests with random input generation"
	@echo "  make fuzzTestEvvmPayNoStaker_sync ----------- Fuzz test sync payments without staking with random values"
	@echo "  make fuzzTestEvvmPayNoStaker_async ---------- Fuzz test async payments without staking with random values"
	@echo "  make fuzzTestEvvmPayStaker_sync ------------- Fuzz test sync payments with staking using random parameters"
	@echo "  make fuzzTestEvvmPayStaker_async ------------ Fuzz test async payments with staking using random parameters"
	@echo "  make fuzzTestEvvmPayMultiple --------------------- Fuzz test batch payments with random recipient arrays"
	@echo "  make fuzzTestEvvmDispersePay --------------------- Fuzz test payment dispersion with random distribution patterns"
	@echo "  make fuzzTestEvvmCaPay --------------------------- Fuzz test CA payments with random contract interactions"
	@echo "  make fuzzTestEvvmDisperseCaPay ------------------- Fuzz test CA payment dispersion with random contract arrays"
	@echo ""
	@echo "-----------------------=Individual Staking Tests=----------------------"
	@echo ""
	@echo "  # Unit Correct Tests - Verify Staking Mechanisms"
	@echo "  make unitTestCorrectStaking ---------------------------------------- Run all Staking unit tests for correct staking behavior"
	@echo "  make unitTestCorrectStakingGoldenStaking --------------------------- Test golden tier staking rewards and mechanics"
	@echo "  make unitTestCorrectStakingPresaleStaking_AsyncExecutionOnPay ------ Test presale staking with async payment execution"
	@echo "  make unitTestCorrectStakingPresaleStaking_SyncExecutionOnPay ------- Test presale staking with sync payment execution"
	@echo "  make unitTestCorrectStakingPublicStaking_AsyncExecutionOnPay ------- Test public staking with async payment execution"
	@echo "  make unitTestCorrectStakingPublicStaking_SyncExecutionOnPay -------- Test public staking with sync payment execution"
	@echo "  make unitTestCorrectStakingPublicServiceStaking_AsyncExecutionOnPay  Test public service staking with async execution"
	@echo "  make unitTestCorrectStakingPublicServiceStaking_SyncExecutionOnPay - Test public service staking with sync execution"
	@echo "  make unitTestCorrectStakingAdminFunctions -------------------------- Test Staking administrative functions and governance"
	@echo ""
	@echo "  # Unit Revert Tests - Verify Staking Error Conditions"
	@echo "  make unitTestRevertStaking --------------------- Run all Staking revert tests for error handling"
	@echo "  make unitTestRevertStakingGoldenStaking -------- Test revert conditions for golden staking operations"
	@echo "  make unitTestRevertStakingPresaleStaking ------- Test revert conditions for presale staking violations"
	@echo "  make unitTestRevertStakingPublicStaking -------- Test revert conditions for public staking violations"
	@echo "  make unitTestRevertStakingPublicServiceStaking - Test revert conditions for public service staking violations"
	@echo "  make unitTestRevertStakingAdminFunctions ------- Test revert conditions for unauthorized Staking admin access"
	@echo ""
	@echo "  # Fuzz Tests - Staking Property Testing"
	@echo "  make fuzzTestStaking --------------------------- Fuzz test general Staking functionality with random inputs"
	@echo "  make fuzzTestStakingGoldenStaking -------------- Fuzz test golden staking with random stake amounts and durations"
	@echo "  make fuzzTestStakingPresaleStaking ------------- Fuzz test presale staking with random participant scenarios"
	@echo "  make fuzzTestStakingPublicStaking -------------- Fuzz test public staking with random user interactions"
	@echo "  make fuzzTestStakingPublicServiceStaking ------- Fuzz test public service staking with random service parameters"
	@echo ""
	@echo "-----------------------=Individual Estimator Tests=----------------------"
	@echo ""
	@echo "  # Unit Correct Tests - Verify Gas Estimation"
	@echo "  make unitTestCorrectEstimator ----------------------- Run all estimator unit tests for correct estimation logic"
	@echo "  make unitTestCorrectEstimatorNotifyNewEpoch --------- Test epoch notification and state transition mechanisms"
	@echo "  make unitTestCorrectEstimatorMakeEstimation --------- Test gas estimation algorithms and accuracy"
	@echo "  make unitTestCorrectEstimatorAdminFunctions --------- Test estimator administrative controls and configuration"
	@echo ""
	@echo "  # Unit Revert Tests - Verify Estimation Error Handling"
	@echo "  make unitTestRevertEstimator --------------------- Test revert conditions for invalid estimation requests"
	@echo ""
	@echo "-----------------------=Individual NameService Tests=----------------------"
	@echo ""
	@echo "  # Unit Correct Tests - Verify Name Service Operations"
	@echo "  make unitTestCorrectNameService ---------------------------------- Run all NameService unit tests for correct functionality"
	@echo "  make unitTestCorrectNameServicePreRegistrationUsername_AsyncExecutionOnPay  Test username pre-registration with async execution"
	@echo "  make unitTestCorrectNameServicePreRegistrationUsername_SyncExecutionOnPay - Test username pre-registration with sync execution"
	@echo "  make unitTestCorrectNameServiceRegistrationUsername_AsyncExecutionOnPay --- Test username registration with async execution"
	@echo "  make unitTestCorrectNameServiceRegistrationUsername_SyncExecutionOnPay ---- Test username registration with sync execution"
	@echo "  make unitTestCorrectNameServiceMakeOffer_AsyncExecutionOnPay -------------- Test username offer creation with async execution"
	@echo "  make unitTestCorrectNameServiceMakeOffer_SyncExecutionOnPay --------------- Test username offer creation with sync execution"
	@echo "  make unitTestCorrectNameServiceWithdrawOffer_AsyncExecutionOnPay ---------- Test offer withdrawal with async execution"
	@echo "  make unitTestCorrectNameServiceWithdrawOffer_SyncExecutionOnPay ----------- Test offer withdrawal with sync execution"
	@echo "  make unitTestCorrectNameServiceAcceptOffer_AsyncExecutionOnPay ------------ Test offer acceptance with async execution"
	@echo "  make unitTestCorrectNameServiceAcceptOffer_SyncExecutionOnPay ------------- Test offer acceptance with sync execution"
	@echo "  make unitTestCorrectNameServiceRenewUsername_AsyncExecutionOnPay ---------- Test username renewal with async execution"
	@echo "  make unitTestCorrectNameServiceRenewUsername_SyncExecutionOnPay ----------- Test username renewal with sync execution"
	@echo "  make unitTestCorrectNameServiceAddCustomMetadata_AsyncExecutionOnPay ------ Test custom metadata addition with async execution"
	@echo "  make unitTestCorrectNameServiceAddCustomMetadata_SyncExecutionOnPay ------- Test custom metadata addition with sync execution"
	@echo "  make unitTestCorrectNameServiceRemoveCustomMetadata_AsyncExecutionOnPay --- Test custom metadata removal with async execution"
	@echo "  make unitTestCorrectNameServiceRemoveCustomMetadata_SyncExecutionOnPay ---- Test custom metadata removal with sync execution"
	@echo "  make unitTestCorrectNameServiceFlushCustomMetadata_AsyncExecutionOnPay ---- Test metadata flush operations with async execution"
	@echo "  make unitTestCorrectNameServiceFlushCustomMetadata_SyncExecutionOnPay ----- Test metadata flush operations with sync execution"
	@echo "  make unitTestCorrectNameServiceFlushUsername_AsyncExecutionOnPay ---------- Test username flush operations with async execution"
	@echo "  make unitTestCorrectNameServiceFlushUsername_SyncExecutionOnPay ----------- Test username flush operations with sync execution"
	@echo "  make unitTestCorrectNameServiceAdminFunctions ---------------------------- Test NameService administrative functions and governance"
	@echo ""
	@echo "  # Unit Revert Tests - Verify Name Service Error Conditions"
	@echo "  make unitTestRevertNameService ------------------------- Run all NameService revert tests for error handling"
	@echo "  make unitTestRevertNameServicePreRegistrationUsername -- Test revert conditions for invalid pre-registrations"
	@echo "  make unitTestRevertNameServiceRegistrationUsername ----- Test revert conditions for invalid username registrations"
	@echo "  make unitTestRevertNameServiceMakeOffer ---------------- Test revert conditions for invalid offer creation"
	@echo "  make unitTestRevertNameServiceWithdrawOffer ------------ Test revert conditions for invalid offer withdrawals"
	@echo "  make unitTestRevertNameServiceAcceptOffer -------------- Test revert conditions for invalid offer acceptance"
	@echo "  make unitTestRevertNameServiceRenewUsername ------------ Test revert conditions for invalid username renewals"
	@echo "  make unitTestRevertNameServiceAddCustomMetadata -------- Test revert conditions for invalid metadata additions"
	@echo "  make unitTestRevertNameServiceRemoveCustomMetadata ----- Test revert conditions for invalid metadata removals"
	@echo "  make unitTestRevertNameServiceFlushCustomMetadata ------ Test revert conditions for invalid metadata flush operations"
	@echo "  make unitTestRevertNameServiceFlushUsername ------------ Test revert conditions for invalid username flush operations"
	@echo "  make unitTestRevertNameServiceAdminFunctions ----------- Test revert conditions for unauthorized NameService admin access"
	@echo ""
	@echo "  # Fuzz Tests - Name Service Property Testing"
	@echo "  make fuzzTestNameServicePreRegistrationUsername ---- Fuzz test pre-registration with random username patterns"
	@echo "  make fuzzTestNameServiceRegistrationUsername ------- Fuzz test registration with random username and payment scenarios"
	@echo "  make fuzzTestNameServiceMakeOffer ------------------ Fuzz test offer creation with random amounts and usernames"
	@echo "  make fuzzTestNameServiceWithdrawOffer -------------- Fuzz test offer withdrawal with random timing and conditions"
	@echo "  make fuzzTestNameServiceAcceptOffer ---------------- Fuzz test offer acceptance with random market scenarios"
	@echo "  make fuzzTestNameServiceRenewUsername -------------- Fuzz test username renewal with random expiration scenarios"
	@echo "  make fuzzTestNameServiceAddCustomMetadata ---------- Fuzz test metadata addition with random key-value pairs"
	@echo "  make fuzzTestNameServiceRemoveCustomMetadata ------- Fuzz test metadata removal with random selection patterns"
	@echo "  make fuzzTestNameServiceFlushCustomMetadata -------- Fuzz test metadata flush with random user scenarios"
	@echo "  make fuzzTestNameServiceFlushUsername -------------- Fuzz test username flush with random ownership scenarios"
	@echo ""
	@echo "-----------------------=Development Tools=----------------------"
	@echo ""
	@echo "  make staticAnalysis ---- Run comprehensive static analysis using Wake detector for security vulnerabilities"
	@echo ""
	@echo "=================================================================================="
	@echo "=================================================================================="
	@echo ""
	@echo "  make testEvvmRevert ----- Run EVVM revert tests"
	@echo "  make fullTestNameService -------- Run all NameService tests"
	@echo "  make testNameService ------------ Run NameService unit tests"
	@echo "  make testNameServiceRevert ------ Run NameService revert tests"
	@echo "  make fullTestStaking ------ Run all staking tests"
	@echo "  make testStaking ---------- Run staking unit tests"
	@echo "  make testStakingRevert ---- Run staking revert tests"
	@echo "  make testEstimator ------ Run estimator tests"
	@echo "  make fullProtocolTest --- Run all protocol tests"
	@echo ""
	@echo "  # Individual EVVM test commands"
	@echo "  make unitTestCorrectEvvm, unitTestRevertEvvm, unitTestFuzzEvvm, etc."
	@echo ""
	@echo "  # Individual Staking test commands"
	@echo "  make unitTestCorrectStaking, unitTestRevertStaking, fuzzTestStaking, etc."
	@echo ""
	@echo "  # Individual Estimator test commands"
	@echo "  make unitTestCorrectEstimator, unitTestRevertEstimator"
	@echo ""
	@echo "  # Individual NameService test commands"
	@echo "  make unitTestCorrectNameService, unitTestRevertNameService, fuzzTestNameServicePreRegistrationUsername, etc."
	@echo ""
	@echo "-----------------------=Fuzz test commands=----------------------"
	@echo ""
	@echo "  EVVM Fuzz tests"
	@echo "    make fuzzTestEvvmPayNoStaker_sync"
	@echo "    make fuzzTestEvvmPayNoStaker_async"
	@echo "    make fuzzTestEvvmPayStaker_sync"
	@echo "    make fuzzTestEvvmPayStaker_async"
	@echo "    make fuzzTestEvvmPayMultiple"
	@echo "    make fuzzTestEvvmDispersePay"
	@echo "    make fuzzTestEvvmCaPay"
	@echo "    make fuzzTestEvvmDisperseCaPay"
	@echo ""
	@echo "  Staking Fuzz tests"
	@echo "    make fuzzTestStaking"
	@echo "    make fuzzTestStakingGoldenStaking"
	@echo "    make fuzzTestStakingPresaleStaking"
	@echo "    make fuzzTestStakingPublicStaking"
	@echo "    make fuzzTestStakingPublicServiceStaking"
	@echo ""
	@echo "  NameService Fuzz tests"
	@echo "    make fuzzTestNameServicePreRegistrationUsername"
	@echo "    make fuzzTestNameServiceRegistrationUsername"
	@echo "    make fuzzTestNameServiceMakeOffer"
	@echo "    make fuzzTestNameServiceWithdrawOffer"
	@echo "    make fuzzTestNameServiceAcceptOffer"
	@echo "    make fuzzTestNameServiceRenewUsername"
	@echo "    make fuzzTestNameServiceAddCustomMetadata"
	@echo "    make fuzzTestNameServiceRemoveCustomMetadata"
	@echo "    make fuzzTestNameServiceFlushCustomMetadata"
	@echo "    make fuzzTestNameServiceFlushUsername"
	@echo ""
	@echo "-----------------------=Other commands=----------------------"
	@echo ""
	@echo "  make staticAnalysis --- Run static analysis and generate report"
	@echo ""
	@echo "---------------------------------------------------------------------------------"
