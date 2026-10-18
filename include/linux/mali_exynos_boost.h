#ifndef _LINUX_MALI_EXYNOS_BOOST_H
#define _LINUX_MALI_EXYNOS_BOOST_H

#include <linux/kconfig.h>
#include <linux/types.h>

/*
 * Ask the Mali Exynos DVFS workaround for a temporary GPU clock boost.
 * Returns 0 if the request was accepted (or ignored because the GPU is
 * powered off), negative on invalid input.
 */
#if IS_ENABLED(CONFIG_MALI_EXYNOS_INTERACTIVE_BOOST)
int mali_exynos_touch_boost(int duration_ms);
#else
static inline int mali_exynos_touch_boost(int duration_ms)
{
	return 0;
}
#endif

#endif /* _LINUX_MALI_EXYNOS_BOOST_H */
