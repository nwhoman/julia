# macOS install guide

You need to have the current Xcode command line utilities installed: run `xcode-select --install` in the terminal. You will need to rerun this terminal command after each macOS update, otherwise you may run into errors involving missing libraries or headers.

The dependent libraries are now built with [BinaryBuilder](https://binarybuilder.org) and will be automatically downloaded. This is the preferred way to build Julia source. In case you want to build them all on your own, you will need a 64-bit gfortran to compile Julia dependencies.
```bash
brew install gcc
```

If you have set `LD_LIBRARY_PATH` or `DYLD_LIBRARY_PATH` in your `.bashrc` or equivalent, Julia may be unable to find various libraries that come bundled with it. These environment variables need to be unset for Julia to work.

## Building Julia

First, make sure you have all the [required
dependencies](https://github.com/JuliaLang/julia/blob/master/doc/src/devdocs/build/build.md#required-build-tools-and-external-libraries) installed.
Then, acquire the source code by cloning the git repository:

    git clone https://github.com/JuliaLang/julia.git

Your result should look similar to this:
![image](https://github.com/nwhoman/julia/assets/102623875/d82e8f8b-c64b-452b-ba8e-d4a965e475a6)

and then use the command prompt to change into the resulting julia directory. 
![image](https://github.com/nwhoman/julia/assets/102623875/d98c1d69-1349-4227-b3e9-838cd852e3b1)

By default you will be building the latest unstable version of
Julia. However, most users should use the [most recent stable version](https://github.com/JuliaLang/julia/releases)
of Julia. You can get this version by running:

    git checkout v1.9.0

Your result should look similar to this:
![image](https://github.com/nwhoman/julia/assets/102623875/a80b4e11-7316-4067-abd2-df7e62f0bb6f)

To build the `julia` executable, run `make` from within the julia directory. This process takes several minutes to complete. The first set of instructions look like this and does not look hopeful for success. This is repeated hundreds of times:
![image](https://github.com/nwhoman/julia/assets/102623875/a79a0c33-840b-45ed-a82c-adaedcb8e5df)

But the process continues through more instructions, this is just an excerpt of many more lines:
![image](https://github.com/nwhoman/julia/assets/102623875/bc8c8453-bbc4-4aba-a5b3-ded3b4d9102f)

Dozens of warnings show:
![image](https://github.com/nwhoman/julia/assets/102623875/0f38b847-6407-4287-84b2-fa5d46a9209b)

The make continues with linking and compiling, this is an example, hundreds of files are listed:
![image](https://github.com/nwhoman/julia/assets/102623875/a8f24c2b-d02a-4e57-ae7d-45e2e027565d)

The final step completes and should look similar to this:
![image](https://github.com/nwhoman/julia/assets/102623875/86082bae-a73a-4526-859d-7a2e18c8786d)


Building Julia requires 2GiB of disk space and approximately 4GiB of virtual memory.

**Note:** The build process will fail badly if any of the build directory's parent directories have spaces or other shell meta-characters such as `$` or `:` in their names (this is due to a limitation in GNU make).


Your first test of Julia determines whether your build is working
properly. From the julia directory, type `make testall`. You should see output that
lists a series of running tests:
![image](https://github.com/nwhoman/julia/assets/102623875/15215409-68f3-4206-8393-825d943caf8e)

this process takes over 20 minutes while the screen does not appear to change, but new tests start
as others finish and are added to the list. My tests included some warnings, but they did not seem 
to be of consequence.
![image](https://github.com/nwhoman/julia/assets/102623875/84b34b45-8ae9-44dd-9cff-438276e88576)

If they complete without error, 
![image](https://github.com/nwhoman/julia/assets/102623875/2a907a93-a708-4569-806f-b3d02f71ba9d)

you should be in good shape to start using Julia.

Once it is built and tested, you can run the `julia` executable. From within the julia directory, run

    ./julia

If successful your output should look like:
![image](https://github.com/nwhoman/julia/assets/102623875/f4c4bb73-3d42-4320-bd92-5b5557b04a37)
