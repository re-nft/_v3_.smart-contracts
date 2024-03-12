# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

########################
## DEPLOYMENT SCRIPTS ##
########################

deploy :; forge script scripts/$(script).s.sol:$(script) \
	--fork-url $(chain) \
	--slow \
	--verify \
	--broadcast \
	-vvv

simulate-deploy :; forge script scripts/$(script).s.sol:$(script) \
	--fork-url $(chain) \
	--slow \
	-vvv \
	--sig 'run(string)' \
	$(chain) \
	-vvv
