#ifndef _NUCLEUS_H_
#define _NUCLEUS_H_

#ifdef	__cplusplus
extern "C" {
#endif

/** @defgroup Nucleus Nucleus library
 *  @{
 */

/*****************************************************************************/
/* Includes section                                                          */
/*****************************************************************************/

#ifdef __linux__
  #define NUCLEUS_EXPORT __attribute__ ((visibility ("default")))
#elif _WIN32
  #include <winsock2.h>
  #ifdef nucleus_EXPORTS
    #define  NUCLEUS_EXPORT __declspec(dllexport)
  #else
    #define  NUCLEUS_EXPORT __declspec(dllimport)
  #endif
#endif

#include <sys/types.h>

#include "nucleus_errno.h"


/*****************************************************************************/
/* Freecounter section                                                       */
/*****************************************************************************/

/* Freecounter module */
/** @defgroup freecounter The freecounter module.
 *  @{
 */

/*********************************************************/
/* Defines section                                       */
/*********************************************************/

#define NUCLEUS_CTL_ENABLE_ADIRS_HTR            0
#define NUCLEUS_CTL_ENABLE_ADIRS_TMP            1
#define NUCLEUS_CTL_GET_EXTERNAL_MODE           2
#define NUCLEUS_CTL_SYNCHRO_OUT_TTL             3


/*********************************************************/
/* Types section                                         */
/*********************************************************/

typedef int32_t nucleus_freecounter_class_t;


/*********************************************************/
/* Prototypes section                                    */
/*********************************************************/

extern NUCLEUS_EXPORT int nucleus_freecounter_sysconfig(char* freecounter_class);
extern NUCLEUS_EXPORT int nucleus_freecounter_init_class(char* freecounter_class, nucleus_freecounter_class_t* id);
extern NUCLEUS_EXPORT int nucleus_freecounter_ctl(nucleus_freecounter_class_t id, uint32_t cmd, void* arg);
extern NUCLEUS_EXPORT int nucleus_freecounter_get32(nucleus_freecounter_class_t id, uint32_t* value);
extern NUCLEUS_EXPORT int nucleus_freecounter_get64(nucleus_freecounter_class_t id, uint64_t* value);
extern NUCLEUS_EXPORT int nucleus_freecounter_free(nucleus_freecounter_class_t id);
/** @} */ // end of freecounter


/*****************************************************************************/
/* Timer section                                                             */
/*****************************************************************************/

/* Timer module */
/** @defgroup timer The timer module.
 *  @{
 */

/*********************************************************/
/* Defines section                                       */
/*********************************************************/

#define NUCLEUS_TIMER_API_USLEEP 1
#define NUCLEUS_TIMER_API_SELECT 2


/*********************************************************/
/* Types section                                         */
/*********************************************************/

typedef int32_t nucleus_timer_class_t;


/*********************************************************/
/* Prototypes section                                    */
/*********************************************************/

extern NUCLEUS_EXPORT int nucleus_timer_init_class(char* timer_class, nucleus_timer_class_t* id);
extern NUCLEUS_EXPORT int nucleus_timer_supported_api(nucleus_timer_class_t id, int32_t* supported_api);
extern NUCLEUS_EXPORT int nucleus_timer_hires_api(nucleus_timer_class_t id, int32_t* hires_api);
extern NUCLEUS_EXPORT int nucleus_timer_usleep(nucleus_timer_class_t id, uint32_t duration);
extern NUCLEUS_EXPORT int nucleus_timer_select(nucleus_timer_class_t id, int32_t n, fd_set* readfs, fd_set* writefds, fd_set* exceptfds, struct timeval* timeout, int* select_return_code);
extern NUCLEUS_EXPORT int nucleus_timer_free(nucleus_timer_class_t id);
/** @} */ // end of timer


/*****************************************************************************/
/* Cpu section                                                               */
/*****************************************************************************/

/* Cpu module */
/** @defgroup cpu The cpu module.
 *  @{
 */

/*********************************************************/
/* Types section                                         */
/*********************************************************/

typedef int32_t nucleus_cpu_id_t;


/*********************************************************/
/* Prototypes section                                    */
/*********************************************************/

extern NUCLEUS_EXPORT int nucleus_cpu_init(void);
extern NUCLEUS_EXPORT uint32_t nucleus_cpu_getnb(void);

extern NUCLEUS_EXPORT int nucleus_cpu_protect(nucleus_cpu_id_t cpu_id);
extern NUCLEUS_EXPORT int nucleus_cpu_unprotect(nucleus_cpu_id_t cpu_id);

extern NUCLEUS_EXPORT int nucleus_cpu_bind_set(pid_t pid, nucleus_cpu_id_t cpu_id);
extern NUCLEUS_EXPORT int nucleus_cpu_bind_get(pid_t pid, nucleus_cpu_id_t* cpu_id);

extern NUCLEUS_EXPORT int nucleus_cpu_tag_create(char* tag_name);
extern NUCLEUS_EXPORT int nucleus_cpu_tag_set(char* tag_name, nucleus_cpu_id_t* cpu_ids, uint32_t number_of_cpu);
extern NUCLEUS_EXPORT int nucleus_cpu_tag_get(char* tag_name, nucleus_cpu_id_t** cpu_ids, uint32_t* number_of_cpu);
extern NUCLEUS_EXPORT int nucleus_cpu_tag_delete(char* tag_name);
extern NUCLEUS_EXPORT int nucleus_cpu_tag_list(char*** tag_names, uint32_t* number_of_tags);
extern NUCLEUS_EXPORT int nucleus_cpu_tag_list_by_cpu(nucleus_cpu_id_t cpu_id, char*** tag_names, uint32_t* number_of_tags);
/** @} */ // end of cpu


/*****************************************************************************/
/* Iniparser section                                                         */
/*****************************************************************************/

/* Iniparser module */
/** @defgroup iniparser The ini file parser module.
 *  @{
 */

/*********************************************************/
/* Defines section                                       */
/*********************************************************/

#define NUCLEUS_INIPARSER_KEY_SIZE 128


/*********************************************************/
/* Types section                                         */
/*********************************************************/

typedef struct _nucleus_iniparser_key_t {
    char key_name[NUCLEUS_INIPARSER_KEY_SIZE];
    int32_t value;
    struct _nucleus_iniparser_key_t* iniparser_key_p;
} nucleus_iniparser_key_t;


/*********************************************************/
/* Prototypes section                                    */
/*********************************************************/

extern NUCLEUS_EXPORT int nucleus_iniparser_init(void);
extern NUCLEUS_EXPORT int nucleus_iniparser_load_ini_file(char* ini_file);
extern NUCLEUS_EXPORT int nucleus_iniparser_load_ini_buf(char* ini_buf, uint32_t ini_buf_size);
extern NUCLEUS_EXPORT int nucleus_iniparser_get_key(char* group, char* key, int32_t* value);
extern NUCLEUS_EXPORT int nucleus_iniparser_get_key_list(char* group, nucleus_iniparser_key_t** key_list);
extern NUCLEUS_EXPORT int nucleus_iniparser_free();

/** @} */ // end of iniparser

/** @} */ // end of nucleus

#ifdef	__cplusplus
}
#endif

#endif /* _NUCLEUS_H_ */
