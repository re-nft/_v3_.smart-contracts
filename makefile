# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

########################
## DEPLOYMENT SCRIPTS ##
########################

deploy :; forge script scripts/$(script).s.sol:$(script) \
	--fork-url $(chain) \
	--with-gas-price $(gas-price) \
	--slow \
	--verify \
	--broadcast \
	--sig 'run(string)' \
	$(chain) \
	-vvv

simulate-deploy :; forge script scripts/$(script).s.sol:$(script) \
	--with-gas-price $(gas-price) \
	--fork-url $(chain) \
	--slow \
	--sig 'run(string)' \
	$(chain) \
	-vvv

#############################
## PROTOCOL UPDATE SCRIPTS ##
#############################

update-policy-activation-status:
	forge script scripts/UpdatePolicyActivationStatus.s.sol:UpdatePolicyActivationStatus \
		--with-gas-price $(gas-price) \
		--fork-url $(chain) \
		--slow \
		--broadcast \
		--sig 'run(string,address,bool)' \
		$(chain) \
		$(policy) \
		$(is-enabled) \
		-vvv
