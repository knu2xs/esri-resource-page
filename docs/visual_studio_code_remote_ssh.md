# Visual Studio Code Remote SSH

You can edit files on a remote server over SSH in VS Code using the official Remote - SSH extension by Microsoft. This extension allows you to work with files and folders on the remote machine as if they were local, while still utilizing all of VS Code's features. [[[1]][1], [[2]][2], [[3]][3]]

## Install the Remote - SSH Extension 

- Open VS Code and go to the Extensions view by clicking the square icon in the sidebar or pressing `Ctrl+Shift+X`. 
- Search for "Remote - SSH". 
- Select the extension by Microsoft and click Install. [[[1]][1], [[4]][4]]

## Connect to a Remote Host 

- Open the Command Palette by pressing `F1` or `Ctrl+Shift+P`. 
- Type and select `Remote-SSH: Connect to Host...`. 
- Enter the connection information in the format `user@hostname` or `user@ip_address` (e.g., `john_doe@server.com`). 
- VS Code will prompt you to select an SSH configuration file to save the connection details. Select the appropriate one for your operating system. 
- Enter your password or use key-based SSH authentication 
for a seamless experience. 
- A new VS Code window will open and connect to the remote server. The status bar in the bottom-left corner will indicate the active SSH connection. [[[1]][1], [[2]][2], [[3]][3], [[4]][4], [[5]][5], [[6]][6], [[7]][7]]  

## Open and Edit Files 

- Once connected, you can open the Explorer view (`Ctrl+Shift+E`) and click **Open Folder** to browse the remote machine's filesystem.
- Select the desired directory on the remote server. 
- You can now open, edit, save, and manage files on the remote server exactly as you would local files, with full access to VS Code features like syntax highlighting, IntelliSense, and integrated source control (Git). [[[2]][2], [[8]][8], [[9]][9], [[10]][10], [[11]][11]]  

## Use the Integrated Terminal 

- Any new terminal you open (`Ctrl+\`\``) within the connected VS Code window will automatically run on the remote server, allowing you to execute commands directly on the host machine. [[[2]][2]]  

For more detailed information, consult the official Visual Studio Code documentation. [[[12]][12], [[13]][13]]

[1]: https://graphite.com/guides/step-by-step-guide-ssh-in-vs-code
[2]: https://www.youtube.com/watch?v=xRe-MizMbG8
[3]: https://code.visualstudio.com/docs/remote/ssh
[4]: https://carleton.ca/scs/2024/vscode-remote-access-and-code-editing/
[5]: https://www.icdsoft.com/en/kb/view/2087_using_visual_studio_code_to_edit_files_remotely_over_ssh
[6]: https://www.youtube.com/watch?v=V6HxxW4huKo
[7]: https://code.visualstudio.com/blogs/2019/07/25/remote-ssh
[8]: https://code.visualstudio.com/docs/remote/ssh-tutorial
[9]: https://cs.wellesley.edu/~cs240/f20/docs/common/vscode/
[10]: https://namastedev.com/blog/setting-up-a-code-editor-vs-code/
[11]: https://cs.wellesley.edu/~cs204/readings/vsc/visual-studio-code.html
[12]: https://www.intel.com/content/www/us/en/docs/oneapi/user-guide-vs-code/2023-1/developing-a-visual-studio-code-project-for-ssh-001.html
[13]: https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=GVSCO_vscodenotes

