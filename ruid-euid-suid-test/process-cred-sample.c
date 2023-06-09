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
	system("cat file-read-only-by-sysadmin");  // file-read-only-by-sysadmin: -r-------- sysadmin sysadmin
	setreuid(geteuid(), geteuid());
	getresuid(&ruid, &euid, &suid);
	printf("RUID: %d, EUID: %d, SUID: %d\n", ruid, euid, suid);
	system("cat file-read-only-by-sysadmin");  // file-read-only-by-sysadmin: -r-------- sysadmin sysadmin
	return 0;
}
