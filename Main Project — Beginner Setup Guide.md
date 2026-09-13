# Main Project

## Beginner Setup Guide — Windows

Follow these steps if you are setting up the Flutter project for the first time.

---

# 1. Install Git

Download **Git for Windows** from the official website:

[Download Git for Windows](https://git-scm.com/download/win?utm_source=chatgpt.com)

During installation, the default options are sufficient.

After installation, open **Command Prompt** and run:

```cmd
git --version
```

You should see a Git version number.

---

# 2. Install Visual Studio Code

Download **Visual Studio Code for Windows**:

[Download Visual Studio Code](https://code.visualstudio.com/download?utm_source=chatgpt.com)

Install VS Code using the recommended options.

VS Code will be used as the main code editor for the project.

---

# 3. Install Flutter

Download the **Flutter SDK for Windows**:

[Flutter — Windows Installation](https://docs.flutter.dev/get-started/install/windows?utm_source=chatgpt.com)

Extract Flutter to a suitable location of your choice.

For example:

```text
C:\src\flutter
```

You may choose another location.

Make sure the Flutter folder contains:

```text
flutter
└── bin
    └── flutter.bat
```

---

# 4. Add Flutter to PATH

Flutter must be added to the Windows PATH so that Flutter commands can be used from Command Prompt or the VS Code terminal.

If Flutter is installed at:

```text
C:\src\flutter
```

add:

```text
C:\src\flutter\bin
```

to the PATH.

### How to add Flutter to PATH

1. Search Windows for **Environment Variables**.
2. Open **Edit the system environment variables**.
3. Click **Environment Variables**.
4. Under **User variables**, select **Path**.
5. Click **Edit**.
6. Click **New**.
7. Add your Flutter `bin` folder.
8. Click **OK** on all windows.

Close and reopen Command Prompt after changing PATH.

---

# 5. Verify Flutter Installation

Open a **new Command Prompt**.

Run:

```cmd
flutter --version
```

Then:

```cmd
dart --version
```

Finally:

```cmd
flutter doctor
```

Make sure there are no critical Flutter installation errors.

> **Note:** You do not need to install Dart separately. Dart is included with Flutter.

---

# 6. Install Flutter Extension in VS Code

Open VS Code.

Press:

```text
Ctrl + Shift + X
```

Search for:

```text
Flutter
```

Install the official **Flutter** extension.

Dart support will also be installed as required.

---

# 7. Get the Main Project from GitHub

Our project repository:

[Main Project — GitHub](https://github.com/AVA-NTHIKA14/Main-Project?utm_source=chatgpt.com)

Open **Command Prompt** or the **VS Code terminal**.

Go to the location where you want to store the project.

Then run:

```cmd
git clone https://github.com/AVA-NTHIKA14/Main-Project.git
```

The project will be downloaded to a folder named:

```text
Main-Project
```

Enter the project folder:

```cmd
cd Main-Project
```

---

# 8. Open the Project in VS Code

From inside the project folder, run:

```cmd
code .
```

This will open the project in VS Code.

If `code` is not recognized, open VS Code manually and select:

**File → Open Folder → Main-Project**

---

# 9. Install Flutter Dependencies

Inside the project folder, run:

```cmd
flutter pub get
```

Flutter will download the packages required by the project.

---

# 10. Check Available Devices

Run:

```cmd
flutter devices
```

Flutter will show the devices available for running the application.

---

# 11. Run the Project

Run:

```cmd
flutter run
```

You can also use the **Run and Debug** option in VS Code.

---

# 12. Before Starting Work

Always get the latest version of the project before making changes:

```cmd
git pull
```

This keeps your local project synchronized with GitHub.

---

# 13. After Making Changes

Check what you changed:

```cmd
git status
```

Add your changes:

```cmd
git add .
```

Create a commit:

```cmd
git commit -m "Describe your changes"
```

Upload your changes:

```cmd
git push
```

---

# Quick Setup

After Git, VS Code and Flutter are installed:

```cmd
git clone https://github.com/AVA-NTHIKA14/Main-Project.git
cd Main-Project
flutter pub get
flutter run
```

---

# Final Checklist

Before starting development:

- [ ] Git installed
- [ ] VS Code installed
- [ ] Flutter SDK installed
- [ ] Flutter added to PATH
- [ ] Flutter extension installed
- [ ] `flutter doctor` checked
- [ ] Main Project cloned from GitHub
- [ ] `flutter pub get` completed
- [ ] A Flutter device is available
- [ ] Project runs successfully

## Important

- Do **not** install Dart separately. Dart is included with Flutter.
- Do **not** upload passwords, API keys, `.env` files, signing keys, or other private credentials to GitHub.
- Always run `git pull` before starting work.
- Commit and push your changes regularly.
