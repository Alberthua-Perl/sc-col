#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int main()
{
    uid_t ruid, euid, suid; 
    getresuid(&ruid, &euid, &suid);
    printf("RUID: %d, EUID: %d, SUID: %d\n", ruid, euid, suid);
    system("/bin/bash -c 'cat file-read-only-by-devops'");    //file read-only by devops: -r-------- devops devops

    setreuid(geteuid(), geteuid());
    getresuid(&ruid, &euid, &suid);
    printf("RUID: %d, EUID: %d, SUID: %d\n", ruid, euid, suid);
    system("cat file-read-only-by-devops");    //file read-only by devops: -r-------- devops devops
    
    return 0;
}
