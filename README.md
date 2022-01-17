following along with https://www.youtube.com/watch?v=FkrpUaGThTQ
Linux or MacOS: docker run --rm -it -v "$(pwd)":/root/env myos-buildenv
Windows (CMD): docker run --rm -it -v "%cd%":/root/env myos-buildenv
Windows (PowerShell): docker run --rm -it -v "${pwd}:/root/env" myos-buildenv
use  ```qemu-system-x86_64 -cdrom dist/x86_64/kernel.iso -L "D:\Program Files (x86)\qemu"``` to run
