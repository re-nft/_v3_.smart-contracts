# Rental Manager

Rental Manager is a gnosis safe module that manages renft business logic.

"It manages rentals" - whilst areas like transfers of NFTs and pyaments it
delegates to Seaport.

We need the ability to change modules, in case we want to adjust the logic of
our implementation in the future. This is easy. The wallet user simply disables
current module and enables a new one. Each rental manager module will have a
version, just like Gnosis Safes have versions. It is not required to implement
any proxies or upgradeable patterns for RentalManager because the use simply
disables older version and enables a new version.
