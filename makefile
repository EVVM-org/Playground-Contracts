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

# Deployment commands
mock: mockToken mockTreasury mockEvvm

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

## EVVM

### Unit tests

#### Correct Tests

unitTestCorrectEvvm:
	@echo "Running all EVVM unit correct tests"
	@forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress 

unitTestCorrectEvvmPayNoMateStaking_async:
	@echo "Running NoMateStaking_async unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_payNoMateStaking_async.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmPayNoMateStaking_sync:
	@echo "Running NoMateStaking_sync unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_payNoMateStaking_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmPayMateStaking_async:
	@echo "Running PayMateStaking_async unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_payMateStaking_async.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectEvvmPayMateStaking_sync:
	@echo "Running PayMateStaking_sync unit correct tests"
	@forge test --match-path test/unit/evvm/correct/unitTestCorrect_EVVM_payMateStaking_sync.t.sol --summary --detailed --gas-report -vvv --show-progress
	
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

unitTestRevertEvvmPayNoMateStaking_sync:
	@echo "Running NoMateStaking_sync unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_payNoMateStaking_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmPayNoMateStaking_async:
	@echo "Running NoMateStaking_async unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_payNoMateStaking_async.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertEvvmPayMateStaking_sync:
	@echo "Running PayMateStaking_sync unit revert tests"
	@forge test --match-path test/unit/evvm/revert/unitTestRevert_EVVM_payMateStaking_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

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
	@forge test --match-contract unitTestFuzz_EVVM --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayNoMateStaking_sync:
	@echo "Running NoMateStaking_sync unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_payNoMateStaking_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayNoMateStaking_async:
	@echo "Running NoMateStaking_async unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_payNoMateStaking_async.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayMateStaking_sync:
	@echo "Running PayMateStaking_sync unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_payMateStaking_sync.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestEvvmPayMateStaking_async:
	@echo "Running PayMateStaking_async unit fuzz tests"
	@forge test --match-path test/fuzz/evvm/fuzzTest_EVVM_payMateStaking_async.t.sol --summary --detailed --gas-report -vvv --show-progress

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

## SMate

### Unit tests

#### Correct Tests

unitTestCorrectSMate:
	@echo "Running all SMate unit correct tests"
	@forge test --match-contract unitTestCorrect_SMate --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMateGoldenStaking:
	@echo "Running GoldenStaking unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_goldenStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMatePresaleStaking_AsyncExecutionOnPay:
	@echo "Running PresaleStaking (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_presaleStaking_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMatePresaleStaking_SyncExecutionOnPay:
	@echo "Running PresaleStaking (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_presaleStaking_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMatePublicStaking_AsyncExecutionOnPay:
	@echo "Running PublicStaking (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_publicStaking_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMatePublicStaking_SyncExecutionOnPay:
	@echo "Running PublicStaking (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_publicStaking_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMatePublicServiceStaking_AsyncExecutionOnPay:
	@echo "Running PublicServiceStaking (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_publicServiceStaking_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMatePublicServiceStaking_SyncExecutionOnPay:
	@echo "Running PublicServiceStaking (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_publicServiceStaking_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectSMateAdminFunctions:
	@echo "Running AdminFunctions unit correct tests"
	@forge test --match-path test/unit/smate/correct/unitTestCorrect_SMate_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Revert Tests

unitTestRevertSMate:
	@echo "Running all SMate unit revert tests"
	@forge test --match-contract unitTestRevert_SMate --summary --detailed --gas-report -vvv --show-progress

unitTestRevertSMateGoldenStaking:
	@echo "Running GoldenStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_SMate_goldenStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertSMatePresaleStaking:
	@echo "Running PresaleStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_SMate_presaleStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertSMatePublicStaking:
	@echo "Running PublicStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_SMate_publicStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertSMatePublicServiceStaking:
	@echo "Running PublicServiceStaking unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_SMate_publicServiceStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertSMateAdminFunctions:
	@echo "Running AdminFunctions unit revert tests"
	@forge test --match-path test/unit/smate/revert/unitTestRevert_SMate_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Fuzz Tests

fuzzTestSMate:
	@echo "Running SMate unit fuzz tests"
	@forge test --match-path test/fuzz/smate/fuzzTest_SMate.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestSMateGoldenStaking:
	@echo "Running GoldenStaking unit fuzz tests"
	@forge test --match-path test/fuzz/sMate/fuzzTest_SMate_goldenStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestSMatePresaleStaking:
	@echo "Running PresaleStaking unit fuzz tests"
	@forge test --match-path test/fuzz/sMate/fuzzTest_SMate_presaleStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestSMatePublicStaking:
	@echo "Running PublicStaking unit fuzz tests"
	@forge test --match-path test/fuzz/sMate/fuzzTest_SMate_publicStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestSMatePublicServiceStaking:
	@echo "Running PublicServiceStaking unit fuzz tests"
	@forge test --match-path test/fuzz/sMate/fuzzTest_SMate_publicServiceStaking.t.sol --summary --detailed --gas-report -vvv --show-progress

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


## MateNameService

### Unit tests

#### Correct Tests

unitTestCorrectMateNameService:
	@echo "Running all MateNameService unit correct tests"
	@forge test --match-contract unitTestCorrect_MateNameService --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServicePreRegistrationUsername_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_preRegistrationUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServicePreRegistrationUsername_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_preRegistrationUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceRegistrationUsername_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_registrationUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceRegistrationUsername_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_registrationUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceMakeOffer_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_makeOffer_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceMakeOffer_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_makeOffer_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceWithdrawOffer_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_withdrawOffer_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceWithdrawOffer_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_withdrawOffer_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceAcceptOffer_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_acceptOffer_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceAcceptOffer_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_acceptOffer_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceRenewUsername_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_renewUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceRenewUsername_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_renewUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceAddCustomMetadata_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_addCustomMetadata_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceAddCustomMetadata_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_addCustomMetadata_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceRemoveCustomMetadata_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_removeCustomMetadata_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceRemoveCustomMetadata_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_removeCustomMetadata_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceFlushCustomMetadata_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_flushCustomMetadata_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceFlushCustomMetadata_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_flushCustomMetadata_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceFlushUsername_AsyncExecutionOnPay:
	@echo "Running MateNameService (async execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_flushUsername_AsyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceFlushUsername_SyncExecutionOnPay:
	@echo "Running MateNameService (sync execution on pay) unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_flushUsername_SyncExecutionOnPay.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestCorrectMateNameServiceAdminFunctions:
	@echo "Running MateNameService unit correct tests"
	@forge test --match-path test/unit/mateNameService/correct/unitTestCorrect_MateNameService_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Revert tests

unitTestRevertMateNameService:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-contract unitTestRevert_MateNameService --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServicePreRegistrationUsername:
	@echo "Running MateNameService unit revert tests"
		@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_preRegistrationUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceRegistrationUsername:
	@echo "Running MateNameService unit revert tests"
		@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_registrationUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceMakeOffer:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_makeOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceWithdrawOffer:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_withdrawOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceAcceptOffer:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_acceptOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceRenewUsername:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_renewUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceAddCustomMetadata:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_addCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceRemoveCustomMetadata:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_removeCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceFlushCustomMetadata:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_flushCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceFlushUsername:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_flushUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

unitTestRevertMateNameServiceAdminFunctions:
	@echo "Running MateNameService unit revert tests"
	@forge test --match-path test/unit/mateNameService/revert/unitTestRevert_MateNameService_adminFunctions.t.sol --summary --detailed --gas-report -vvv --show-progress

#### Fuzz tests

fuzzTestMateNameServicePreRegistrationUsername:
	@echo "Running MateNameService fuzz tests for preRegistrationUsername"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_preRegistrationUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceRegistrationUsername:
	@echo "Running MateNameService fuzz tests for registrationUsername"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_registrationUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceMakeOffer:
	@echo "Running MateNameService fuzz tests for makeOffer"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_makeOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceWithdrawOffer:
	@echo "Running MateNameService fuzz tests for withdrawOffer"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_withdrawOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceAcceptOffer:
	@echo "Running MateNameService fuzz tests for acceptOffer"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_acceptOffer.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceRenewUsername:
	@echo "Running MateNameService fuzz tests for renewUsername"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_renewUsername.t.sol --summary --detailed --gas-report -vvvv --show-progress

fuzzTestMateNameServiceAddCustomMetadata:
	@echo "Running MateNameService fuzz tests for addCustomMetadata"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_addCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceRemoveCustomMetadata:
	@echo "Running MateNameService fuzz tests for removeCustomMetadata"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_removeCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceFlushCustomMetadata:
	@echo "Running MateNameService fuzz tests for flushCustomMetadata"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_flushCustomMetadata.t.sol --summary --detailed --gas-report -vvv --show-progress

fuzzTestMateNameServiceFlushUsername:
	@echo "Running MateNameService fuzz tests for flushUsername"
	@forge test --match-path test/fuzz/mns/fuzzTest_MateNameService_flushUsername.t.sol --summary --detailed --gas-report -vvv --show-progress

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
	@echo "  make fullProtocolTest --- Execute complete test suite for all protocol components (EVVM + SMate + MNS + Estimator)"
	@echo ""
	@echo "  # EVVM Test Suite"
	@echo "  make fullTestEvvm ------- Run comprehensive EVVM test suite (unit correct + revert + fuzz tests)"
	@echo "  make testEvvm ----------- Execute all EVVM unit tests that verify correct functionality"
	@echo "  make testEvvmRevert ----- Execute all EVVM unit tests that verify proper revert conditions"
	@echo ""
	@echo "  # SMate Test Suite"
	@echo "  make fullTestSMate ------ Run comprehensive SMate staking test suite (unit correct + revert + fuzz tests)"
	@echo "  make testSMate ---------- Execute all SMate unit tests that verify correct staking functionality"
	@echo "  make testSMateRevert ---- Execute all SMate unit tests that verify proper revert conditions"
	@echo ""
	@echo "  # MateNameService (MNS) Test Suite"
	@echo "  make fullTestMNS -------- Run comprehensive MNS test suite (unit correct + revert + fuzz tests)"
	@echo "  make testMNS ------------ Execute all MNS unit tests that verify correct name service functionality"
	@echo "  make testMNSRevert ------ Execute all MNS unit tests that verify proper revert conditions"
	@echo ""
	@echo "  # Estimator Test Suite"
	@echo "  make testEstimator ------ Execute all estimator tests for gas estimation and epoch management"
	@echo ""
	@echo "-----------------------=Individual EVVM Tests=----------------------"
	@echo ""
	@echo "  # Unit Correct Tests - Verify Expected Behavior"
	@echo "  make unitTestCorrectEvvm ------------------------- Run all EVVM unit tests for correct functionality"
	@echo "  make unitTestCorrectEvvmPayNoMateStaking_async --- Test async payments without mate staking requirements"
	@echo "  make unitTestCorrectEvvmPayNoMateStaking_sync ---- Test sync payments without mate staking requirements"
	@echo "  make unitTestCorrectEvvmPayMateStaking_async ----- Test async payments with mate staking integration"
	@echo "  make unitTestCorrectEvvmPayMateStaking_sync ------ Test sync payments with mate staking integration"
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
	@echo "  make unitTestRevertEvvmPayNoMateStaking_sync ----- Test revert conditions for sync payments without staking"
	@echo "  make unitTestRevertEvvmPayNoMateStaking_async ---- Test revert conditions for async payments without staking"
	@echo "  make unitTestRevertEvvmPayMateStaking_sync ------- Test revert conditions for sync payments with staking"
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
	@echo "  make fuzzTestEvvmPayNoMateStaking_sync ----------- Fuzz test sync payments without staking with random values"
	@echo "  make fuzzTestEvvmPayNoMateStaking_async ---------- Fuzz test async payments without staking with random values"
	@echo "  make fuzzTestEvvmPayMateStaking_sync ------------- Fuzz test sync payments with staking using random parameters"
	@echo "  make fuzzTestEvvmPayMateStaking_async ------------ Fuzz test async payments with staking using random parameters"
	@echo "  make fuzzTestEvvmPayMultiple --------------------- Fuzz test batch payments with random recipient arrays"
	@echo "  make fuzzTestEvvmDispersePay --------------------- Fuzz test payment dispersion with random distribution patterns"
	@echo "  make fuzzTestEvvmCaPay --------------------------- Fuzz test CA payments with random contract interactions"
	@echo "  make fuzzTestEvvmDisperseCaPay ------------------- Fuzz test CA payment dispersion with random contract arrays"
	@echo ""
	@echo "-----------------------=Individual SMate Tests=----------------------"
	@echo ""
	@echo "  # Unit Correct Tests - Verify Staking Mechanisms"
	@echo "  make unitTestCorrectSMate ---------------------------------------- Run all SMate unit tests for correct staking behavior"
	@echo "  make unitTestCorrectSMateGoldenStaking --------------------------- Test golden tier staking rewards and mechanics"
	@echo "  make unitTestCorrectSMatePresaleStaking_AsyncExecutionOnPay ------ Test presale staking with async payment execution"
	@echo "  make unitTestCorrectSMatePresaleStaking_SyncExecutionOnPay ------- Test presale staking with sync payment execution"
	@echo "  make unitTestCorrectSMatePublicStaking_AsyncExecutionOnPay ------- Test public staking with async payment execution"
	@echo "  make unitTestCorrectSMatePublicStaking_SyncExecutionOnPay -------- Test public staking with sync payment execution"
	@echo "  make unitTestCorrectSMatePublicServiceStaking_AsyncExecutionOnPay  Test public service staking with async execution"
	@echo "  make unitTestCorrectSMatePublicServiceStaking_SyncExecutionOnPay - Test public service staking with sync execution"
	@echo "  make unitTestCorrectSMateAdminFunctions -------------------------- Test SMate administrative functions and governance"
	@echo ""
	@echo "  # Unit Revert Tests - Verify Staking Error Conditions"
	@echo "  make unitTestRevertSMate --------------------- Run all SMate revert tests for error handling"
	@echo "  make unitTestRevertSMateGoldenStaking -------- Test revert conditions for golden staking operations"
	@echo "  make unitTestRevertSMatePresaleStaking ------- Test revert conditions for presale staking violations"
	@echo "  make unitTestRevertSMatePublicStaking -------- Test revert conditions for public staking violations"
	@echo "  make unitTestRevertSMatePublicServiceStaking - Test revert conditions for public service staking violations"
	@echo "  make unitTestRevertSMateAdminFunctions ------- Test revert conditions for unauthorized SMate admin access"
	@echo ""
	@echo "  # Fuzz Tests - Staking Property Testing"
	@echo "  make fuzzTestSMate --------------------------- Fuzz test general SMate functionality with random inputs"
	@echo "  make fuzzTestSMateGoldenStaking -------------- Fuzz test golden staking with random stake amounts and durations"
	@echo "  make fuzzTestSMatePresaleStaking ------------- Fuzz test presale staking with random participant scenarios"
	@echo "  make fuzzTestSMatePublicStaking -------------- Fuzz test public staking with random user interactions"
	@echo "  make fuzzTestSMatePublicServiceStaking ------- Fuzz test public service staking with random service parameters"
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
	@echo "-----------------------=Individual MNS Tests=----------------------"
	@echo ""
	@echo "  # Unit Correct Tests - Verify Name Service Operations"
	@echo "  make unitTestCorrectMateNameService ---------------------------------- Run all MNS unit tests for correct functionality"
	@echo "  make unitTestCorrectMateNameServicePreRegistrationUsername_AsyncExecutionOnPay  Test username pre-registration with async execution"
	@echo "  make unitTestCorrectMateNameServicePreRegistrationUsername_SyncExecutionOnPay - Test username pre-registration with sync execution"
	@echo "  make unitTestCorrectMateNameServiceRegistrationUsername_AsyncExecutionOnPay --- Test username registration with async execution"
	@echo "  make unitTestCorrectMateNameServiceRegistrationUsername_SyncExecutionOnPay ---- Test username registration with sync execution"
	@echo "  make unitTestCorrectMateNameServiceMakeOffer_AsyncExecutionOnPay -------------- Test username offer creation with async execution"
	@echo "  make unitTestCorrectMateNameServiceMakeOffer_SyncExecutionOnPay --------------- Test username offer creation with sync execution"
	@echo "  make unitTestCorrectMateNameServiceWithdrawOffer_AsyncExecutionOnPay ---------- Test offer withdrawal with async execution"
	@echo "  make unitTestCorrectMateNameServiceWithdrawOffer_SyncExecutionOnPay ----------- Test offer withdrawal with sync execution"
	@echo "  make unitTestCorrectMateNameServiceAcceptOffer_AsyncExecutionOnPay ------------ Test offer acceptance with async execution"
	@echo "  make unitTestCorrectMateNameServiceAcceptOffer_SyncExecutionOnPay ------------- Test offer acceptance with sync execution"
	@echo "  make unitTestCorrectMateNameServiceRenewUsername_AsyncExecutionOnPay ---------- Test username renewal with async execution"
	@echo "  make unitTestCorrectMateNameServiceRenewUsername_SyncExecutionOnPay ----------- Test username renewal with sync execution"
	@echo "  make unitTestCorrectMateNameServiceAddCustomMetadata_AsyncExecutionOnPay ------ Test custom metadata addition with async execution"
	@echo "  make unitTestCorrectMateNameServiceAddCustomMetadata_SyncExecutionOnPay ------- Test custom metadata addition with sync execution"
	@echo "  make unitTestCorrectMateNameServiceRemoveCustomMetadata_AsyncExecutionOnPay --- Test custom metadata removal with async execution"
	@echo "  make unitTestCorrectMateNameServiceRemoveCustomMetadata_SyncExecutionOnPay ---- Test custom metadata removal with sync execution"
	@echo "  make unitTestCorrectMateNameServiceFlushCustomMetadata_AsyncExecutionOnPay ---- Test metadata flush operations with async execution"
	@echo "  make unitTestCorrectMateNameServiceFlushCustomMetadata_SyncExecutionOnPay ----- Test metadata flush operations with sync execution"
	@echo "  make unitTestCorrectMateNameServiceFlushUsername_AsyncExecutionOnPay ---------- Test username flush operations with async execution"
	@echo "  make unitTestCorrectMateNameServiceFlushUsername_SyncExecutionOnPay ----------- Test username flush operations with sync execution"
	@echo "  make unitTestCorrectMateNameServiceAdminFunctions ---------------------------- Test MNS administrative functions and governance"
	@echo ""
	@echo "  # Unit Revert Tests - Verify Name Service Error Conditions"
	@echo "  make unitTestRevertMateNameService ------------------------- Run all MNS revert tests for error handling"
	@echo "  make unitTestRevertMateNameServicePreRegistrationUsername -- Test revert conditions for invalid pre-registrations"
	@echo "  make unitTestRevertMateNameServiceRegistrationUsername ----- Test revert conditions for invalid username registrations"
	@echo "  make unitTestRevertMateNameServiceMakeOffer ---------------- Test revert conditions for invalid offer creation"
	@echo "  make unitTestRevertMateNameServiceWithdrawOffer ------------ Test revert conditions for invalid offer withdrawals"
	@echo "  make unitTestRevertMateNameServiceAcceptOffer -------------- Test revert conditions for invalid offer acceptance"
	@echo "  make unitTestRevertMateNameServiceRenewUsername ------------ Test revert conditions for invalid username renewals"
	@echo "  make unitTestRevertMateNameServiceAddCustomMetadata -------- Test revert conditions for invalid metadata additions"
	@echo "  make unitTestRevertMateNameServiceRemoveCustomMetadata ----- Test revert conditions for invalid metadata removals"
	@echo "  make unitTestRevertMateNameServiceFlushCustomMetadata ------ Test revert conditions for invalid metadata flush operations"
	@echo "  make unitTestRevertMateNameServiceFlushUsername ------------ Test revert conditions for invalid username flush operations"
	@echo "  make unitTestRevertMateNameServiceAdminFunctions ----------- Test revert conditions for unauthorized MNS admin access"
	@echo ""
	@echo "  # Fuzz Tests - Name Service Property Testing"
	@echo "  make fuzzTestMateNameServicePreRegistrationUsername ---- Fuzz test pre-registration with random username patterns"
	@echo "  make fuzzTestMateNameServiceRegistrationUsername ------- Fuzz test registration with random username and payment scenarios"
	@echo "  make fuzzTestMateNameServiceMakeOffer ------------------ Fuzz test offer creation with random amounts and usernames"
	@echo "  make fuzzTestMateNameServiceWithdrawOffer -------------- Fuzz test offer withdrawal with random timing and conditions"
	@echo "  make fuzzTestMateNameServiceAcceptOffer ---------------- Fuzz test offer acceptance with random market scenarios"
	@echo "  make fuzzTestMateNameServiceRenewUsername -------------- Fuzz test username renewal with random expiration scenarios"
	@echo "  make fuzzTestMateNameServiceAddCustomMetadata ---------- Fuzz test metadata addition with random key-value pairs"
	@echo "  make fuzzTestMateNameServiceRemoveCustomMetadata ------- Fuzz test metadata removal with random selection patterns"
	@echo "  make fuzzTestMateNameServiceFlushCustomMetadata -------- Fuzz test metadata flush with random user scenarios"
	@echo "  make fuzzTestMateNameServiceFlushUsername -------------- Fuzz test username flush with random ownership scenarios"
	@echo ""
	@echo "-----------------------=Development Tools=----------------------"
	@echo ""
	@echo "  make staticAnalysis ---- Run comprehensive static analysis using Wake detector for security vulnerabilities"
	@echo ""
	@echo "=================================================================================="
	@echo "=================================================================================="
	@echo ""
	@echo "  make testEvvmRevert ----- Run EVVM revert tests"
	@echo "  make fullTestMNS -------- Run all MNS tests"
	@echo "  make testMNS ------------ Run MNS unit tests"
	@echo "  make testMNSRevert ------ Run MNS revert tests"
	@echo "  make fullTestSMate ------ Run all sMate tests"
	@echo "  make testSMate ---------- Run sMate unit tests"
	@echo "  make testSMateRevert ---- Run sMate revert tests"
	@echo "  make testEstimator ------ Run estimator tests"
	@echo "  make fullProtocolTest --- Run all protocol tests"
	@echo ""
	@echo "  # Individual EVVM test commands"
	@echo "  make unitTestCorrectEvvm, unitTestRevertEvvm, unitTestFuzzEvvm, etc."
	@echo ""
	@echo "  # Individual SMate test commands"
	@echo "  make unitTestCorrectSMate, unitTestRevertSMate, fuzzTestSMate, etc."
	@echo ""
	@echo "  # Individual Estimator test commands"
	@echo "  make unitTestCorrectEstimator, unitTestRevertEstimator"
	@echo ""
	@echo "  # Individual MateNameService test commands"
	@echo "  make unitTestCorrectMateNameService, unitTestRevertMateNameService, fuzzTestMateNameServicePreRegistrationUsername, etc."
	@echo ""
	@echo "-----------------------=Fuzz test commands=----------------------"
	@echo ""
	@echo "  EVVM Fuzz tests"
	@echo "    make fuzzTestEvvmPayNoMateStaking_sync"
	@echo "    make fuzzTestEvvmPayNoMateStaking_async"
	@echo "    make fuzzTestEvvmPayMateStaking_sync"
	@echo "    make fuzzTestEvvmPayMateStaking_async"
	@echo "    make fuzzTestEvvmPayMultiple"
	@echo "    make fuzzTestEvvmDispersePay"
	@echo "    make fuzzTestEvvmCaPay"
	@echo "    make fuzzTestEvvmDisperseCaPay"
	@echo ""
	@echo "  SMate Fuzz tests"
	@echo "    make fuzzTestSMate"
	@echo "    make fuzzTestSMateGoldenStaking"
	@echo "    make fuzzTestSMatePresaleStaking"
	@echo "    make fuzzTestSMatePublicStaking"
	@echo "    make fuzzTestSMatePublicServiceStaking"
	@echo ""
	@echo "  MNS Fuzz tests"
	@echo "    make fuzzTestMateNameServicePreRegistrationUsername"
	@echo "    make fuzzTestMateNameServiceRegistrationUsername"
	@echo "    make fuzzTestMateNameServiceMakeOffer"
	@echo "    make fuzzTestMateNameServiceWithdrawOffer"
	@echo "    make fuzzTestMateNameServiceAcceptOffer"
	@echo "    make fuzzTestMateNameServiceRenewUsername"
	@echo "    make fuzzTestMateNameServiceAddCustomMetadata"
	@echo "    make fuzzTestMateNameServiceRemoveCustomMetadata"
	@echo "    make fuzzTestMateNameServiceFlushCustomMetadata"
	@echo "    make fuzzTestMateNameServiceFlushUsername"
	@echo ""
	@echo "-----------------------=Other commands=----------------------"
	@echo ""
	@echo "  make staticAnalysis --- Run static analysis and generate report"
	@echo ""
	@echo "---------------------------------------------------------------------------------"