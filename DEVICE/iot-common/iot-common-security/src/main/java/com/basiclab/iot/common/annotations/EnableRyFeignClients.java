package com.basiclab.iot.common.annotations;

import java.lang.annotation.*;

/**
 * 自定义feign注解
 * 添加basePackages路径
 * 
 * @author 翱翔的雄库鲁
 * @email andywebjava@163.com
 * @wechat EasyAIoT2025
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface EnableRyFeignClients {
}
