# EpicGamesStarter

NOTE: the code in this repository is no longer used in favor of a executable that only utilises the log in portion of Legendary [here](https://github.com/whichtwix/legendary/tree/master/CSharpLegendary).

Games exist on the epic games platform that require authentication to start up to their Main screen. These are provided by the launcher, but to open the game in the non installation folder takes some work to authenticate. [Legendary](https://github.com/derrod/legendary) takes the 
approach of using login credentials and http requests to do this. EpicGamesStarter takes a different approach of letting the launcher generate these for us and then retrieving them.