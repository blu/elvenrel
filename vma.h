#ifndef __vma_H__
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

struct char_ptr_arr_t {
	size_t count;
	char **arr;
};

void vma_process(struct char_ptr_arr_t *areas);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* __vma_H__ */
