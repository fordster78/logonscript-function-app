# LogonScript Function App

Azure Function App to serve as a middleware for a logon script solution for cloud managed devices.

## Folder overview

- function-app contains the function app code that will be deployed to Azure

## Pre-Requisites for local function app development and deployment

To develop and deploy the function app contained within this repository, please make sure you have the following reqs on your development environment.

- [Visual Studio Code](https://code.visualstudio.com/)
- The [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) version 2.x or later. The Core Tools package is downloaded and installed automatically when you start the project locally. Core Tools includes the entire Azure Functions runtime, so download and installation might take some time.
- [PowerShell 7](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows) recommended.
- Both [.NET Core 3.1](https://www.microsoft.com/net/download) runtime and [.NET Core 2.1 runtime](https://dotnet.microsoft.com/download/dotnet-core/2.1).
- The [PowerShell extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell).
- The [Azure Functions extension for Visual Studio Code](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code?tabs=powershell#install-the-azure-functions-extension)

## Configuration

The solution in this repository requires a little bit of configuration - namely, building your drivemaps.json file, configuring an AAD application and creating and publishing a function app.

### drivemaps.json

Arguable the heart of this solution, the drivemaps.json file contains the logic of your logon script solution. Use the contained file as a reference to build your own based on your business requirements.

### AAD app registration

- Create an AAD application with the following Graph API permissions:

| Permission Name | Permission Scope |
|--- | --- |
| Directory.Read.All | Application|
| Group.Read.All | Application |
| User.Read.All | Application |

- Capture the application ID and generate a client secret.

### Function app

- Create a function app using PowerShell Core as the runtime stack.
- Add the following application settings to the configuration of the function app:

| Setting Name | Setting Value |
| --- | --- |
| CLIENT_ID | The application id of your AAD App |
| CLIENT_SEC | The client secret of your AAD App |
| RES_URL | https://graph.microsoft.com |
| TENANT_ID | The AAD tenant ID |

- Create a new function inside your newly created function app.
- Replace the sample code with the contents of run.ps1
- Copy your modified drivemaps.json file to the root of the function.
- Save the changes and make note of the function URL


## Credits
This Repository is based on the solution provided by [tabs-not-spaces](https://github.com/tabs-not-spaces/Intune.Logonscript.FunctionApp)