#ifndef _NUCLEUS_ERRNO_H_
#define _NUCLEUS_ERRNO_H_

/*****************************************************************************/
/* Includes section                                                          */
/*****************************************************************************/

#include <stdint.h>


/*****************************************************************************/
/* Defines section                                                           */
/*****************************************************************************/

/* Errors */
#define NUCLEUS_OK         0
#define NUCLEUS_EFAILED    1
#define NUCLEUS_ENOTAVAIL  2
#define NUCLEUS_EINIT      3
#define NUCLEUS_EINVAL     4
#define NUCLEUS_EPERM      5
#define NUCLEUS_EINTR      6
#define NUCLEUS_EEXIST     7
#define NUCLEUS_EBADFILE   8
#define NUCLEUS_EBADGROUP  9
#define NUCLEUS_EBADKEY   10


/*****************************************************************************/
/* Prototypes section                                                        */
/*****************************************************************************/

extern NUCLEUS_EXPORT char* nucleus_error_name(uint32_t nucleus_error);
extern NUCLEUS_EXPORT char* nucleus_error_descr(uint32_t nucleus_error);

#endif /* _NUCLEUS_ERRNO_H_ */
