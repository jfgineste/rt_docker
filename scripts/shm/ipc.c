#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <mqueue.h>
#include "ipc.h"


#define Q_NAME    "/docker_ipc"
#define MAX_SIZE  1024
#define M_EXIT    "done"
#define SRV_FLAG  "-writer"
#define COPYMODE  0644 // rw-r--r--
#define NUMBER_OF_MESSAGES 500

/***************************************************************************************
 * The aim of this program is to test the IPC utilization capacity of Docker
 * "writer" creates a message queue and broadcasts messages on it
 * "reader" pulls from the message queue and writes messages to the logs
 *
 * 1 - run "docker run -d --name ipc_writer shm -writer"
 * 2 - run "docker run -d --name ipc_reader --ipc container:ipc_writer shm -reader"
 * 3 - run "docker logs ipc_writer"
 * 4 - run "docker logs ipc_reader"
 *
 ***************************************************************************************/
 

int main(int argc, char *argv[])
{
    if (argc < 2)
    {
    	printf("writer starting...\n");
        writer();
    }
    else if (argc >= 2 && 0 == strncmp(argv[1], SRV_FLAG, strlen(SRV_FLAG)))
    {
    	printf("writer starting...\n");
        writer();
    }
    else
    {
    	printf("reader starting...\n");
        reader();
    }
}


int writer()
{
    mqd_t mq; 			// message queue descriptor
    struct mq_attr attr;  	// messaque queue attributes (flag, size, msg size, current msg id)
    char buffer[MAX_SIZE]; 	// buffer
    int msg, i; 		// message id

    attr.mq_flags = 0;
    attr.mq_maxmsg = 10;
    attr.mq_msgsize = MAX_SIZE;
    attr.mq_curmsgs = 0;

    mq = mq_open(Q_NAME, O_CREAT | O_WRONLY, COPYMODE, &attr); // creates a message queue

    srand(time(NULL)); /* random seed */

    i = 0;
    
    // generator
    while (i < NUMBER_OF_MESSAGES) 
    {
        msg = rand() % 256;			// generates a random byte
        memset(buffer, 0, MAX_SIZE); 		// buffer initialization
        sprintf(buffer, "%x", msg);		// bufferizes random byte
        printf("Written [%d] : %s\n", i, buffer); 
        fflush(stdout);				// erases buffer and forces writing
        mq_send(mq, buffer, MAX_SIZE, 0);	// sends to message queue
        i=i+1;					// next message
    }
    memset(buffer, 0, MAX_SIZE);		// buffer reinitialization
    sprintf(buffer, M_EXIT);			// done !
    mq_send(mq, buffer, MAX_SIZE, 0); 		// sends closure msg to mq

    mq_close(mq);
    mq_unlink(Q_NAME);
    return 0;
}

int reader()
{
    struct mq_attr attr;
    int msg_id;
    char buffer[MAX_SIZE + 1];
    ssize_t bytes_read;
    mqd_t mq = mq_open(Q_NAME, O_RDONLY);	// read only access to the buffer
    if ((mqd_t)-1 == mq) {
        printf("[ERROR] Either there is no writer or there is no available Shared Memory.\n");
        exit(1);
    }
    msg_id = 0;
    do {
        bytes_read = mq_receive(mq, buffer, MAX_SIZE, NULL);
        buffer[bytes_read] = '\0';
        printf("Read [%d] : %s\n", msg_id, buffer);
        msg_id++;
    } while (0 != strncmp(buffer, M_EXIT, strlen(M_EXIT))); 

    mq_close(mq);
    return 0;
}
