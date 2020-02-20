# iOS Project Generator Script

## Installation

Download [install.sh](install.sh) and run it from terminal:

```
curl -o- https://raw.githubusercontent.com/ladeiko/ios-project-generator/master/install.sh | bash
```

## Usage 

To generate new iOS project just run in terminal:

```
ios-project-generator --app ~/Desktop/MyProject
```

After completion you will find ready to use iOS application files in ~/Desktop/MyProject.
Product will be named MyProject. Name for the project is taken from last component of the path. If you want to use custom name pass it with *--name* option:

```
ios-project-generator --app ~/Desktop/MyProject --name CustomName
```

To specify type of generated application pass the template by *--type* option:

```
ios-project-generator --type AppType --app ~/Desktop/MyProject --name CustomName
```

Currently supported application types:

 * viper (used by default)

## LICENSE

See [LICENSE](LICENSE)



