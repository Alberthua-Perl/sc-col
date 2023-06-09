#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>

#define BUFF_SIZE 100

void read_file() {
	FILE *fp;
	char buffer[BUFF_SIZE];

	/* Open file for both reading and writing */
	fp = fopen("file-read-only-by-sysadmin", "r");
	/* Read and display data */
	fread(buffer, BUFF_SIZE - 1, sizeof(char), fp);
	printf("%s\n", buffer);
	fclose(fp);
}

int main()
{
	uid_t ruid, euid, suid; 
	getresuid(&ruid, &euid, &suid);
	printf("RUID: %d, EUID: %d, SUID: %d\n", ruid, euid, suid);
	read_file();  // file-read-only-by-sysadmin: -r-------- sysadmin sysadmin
	setreuid(geteuid(), geteuid());
	getresuid(&ruid, &euid, &suid);
	printf("RUID: %d, EUID: %d, SUID: %d\n", ruid, euid, suid);
	read_file();  // file-read-only-by-sysadmin: -r-------- sysadmin sysadmin
	return 0;
}
