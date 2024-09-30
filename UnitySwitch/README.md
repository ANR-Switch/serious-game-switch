# General Information

Includes a Unity project based on the [SIMPLE toolchain](https://github.com/project-SIMPLE/simple.toolchain) for coupling a GAMA model to a WebGL interface developed in Unity.

More specifically, this project works with the [SIMPLE plugin](https://github.com/project-SIMPLE/simple.toolchain/tree/2024-06/GAMA%20Plugin) for GAMA. It enables most of the functionalities provided by the SIMPLE toolchain to be used within a Web interface: message exchange between GAMA and the Web interface, sending from GAMA objects/agents that are displayed in 3D in the Web interface (Webgl), sending information on grids/terrain from GAMA, animation control from GAMA, etc.

It is also possible to use the tool included in the SIMPLE plugin for GAMA to generate an overmodel to link an existing model to a Web interface. 

# Installation (for Developers)

> [!WARNING]
> The project is being developped using **Unity Editor 2022.3.5f1**. Although it should work with newer versions, as is doesn't use any version-specific features (for now), it is strongly recommanded to use exactly the same Editor version.



To be able to use this project, use this different step:
*  Add the project in Unity Hub (Add Button, then select the folder UnitySwitch).
*  Click on the project from Unity Hub to open it.
Once the project is opened in Unity, if you have any errors, make sure that **Newtonsoft Json** is installed. Normaly, [cloning this repo](https://github.com/ANR-Switch/serious-game-switch.git) should ensure that it is installed. But if it's not the case, follow the tutorial on this [link](https://github.com/applejag/Newtonsoft.Json-for-Unity/wiki/Install-official-via-UPM).
* For GAMA, be sure to have the SIMPLE plugin installed. Information about the installation of this plugin can be found [here](https://github.com/project-SIMPLE/simple.toolchain/tree/2024-06/GAMA%20Plugin)

 
