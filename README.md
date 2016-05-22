# Configuration Manager Auto Packager

The purpose of this project is to make tools to automate much of the application packaging process.

The script called "App Creator - Hackathon (Alpha).ps1" is the hackaton project I made for MMS. It is very alpha and will probably fail in most environments. The script AutoPackager.ps1 is a more generalized version that will work in most environments.
That script is still being worked on and is not ready to be put in production. Check back here in a week or two for a more complete version.

AutoPackger is still a major work in progress.

To do:

* Collections
    * Create collection function
        * needs to verify collection doesn't exist
        * put collection in correct folder
* Applications
    * Create application function
        * verify application doesn't exist
        * put application in correct folder
    * Distribute application content
        * Work off DP name, not just FQDN
    * Deploy application to collection
* Hyper-V support    