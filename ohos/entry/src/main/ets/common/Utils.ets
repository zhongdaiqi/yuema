/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights reserved.
 */

import promptAction from '@ohos.promptAction';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ErrorCode } from './ErrorCodeEntity';
import { authentication } from '@kit.AccountKit';

// 定义华为ID数据接口
export interface HuaweiIDData {
  authorizationCode?: string;
  openId?: string;
  unionId?: string;
  extraInfo?: {
    quickLoginAnonymousPhone?: string;
  };
}

// 定义返回结果类型
interface AnonymousPhoneResult {
  quickLoginAnonymousPhone?: string;
}

// 预取号阶段：获取匿名手机号
export async function getUserProfile(): Promise<AnonymousPhoneResult | null> {
  try {
    // 创建授权请求，请求匿名手机号信息
    const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    // 配置scope以获取匿名手机号
    authRequest.scopes = ['quickLoginAnonymousPhone'];
    // 设置forceAuthorization为false以实现静默获取
    authRequest.forceAuthorization = false;
    
    const controller = new authentication.AuthenticationController();
    const response: authentication.AuthorizationWithHuaweiIDResponse = await controller.executeRequest(authRequest);
    
    // 检查响应结构并获取用户信息
    if (response && response.data) {
      // 直接访问response.data属性
      const data = response.data as HuaweiIDData;
      if (data) {
        // 尝试从extraInfo中获取信息
        if (data.extraInfo) {
          const extraInfo = data.extraInfo;
          // 根据API文档，获取匿名手机号
          const quickLoginAnonymousPhone = extraInfo.quickLoginAnonymousPhone || undefined;
          
          return {
            quickLoginAnonymousPhone: quickLoginAnonymousPhone
          };
        }
      }
    }
  } catch (error) {
    hilog.error(0x0000, 'Utils', `获取匿名手机号失败: ${JSON.stringify(error)}`);
    return null;
  }
  return null;
}

// 错误处理函数
export function handleLoginError(error: BusinessError): void {
  hilog.error(0x0000, 'Utils', `登录错误: ${JSON.stringify(error)}`);
  
  // 根据错误码处理不同情况
  switch (error.code) {
    case 1001502001:
      // 用户未登录华为账号
      hilog.info(0x0000, 'Utils', '用户未登录华为账号，需要展示其他登录方式');
      break;
    case 1001502002:
      // 用户取消授权
      hilog.info(0x0000, 'Utils', '用户取消授权');
      break;
    default:
      hilog.info(0x0000, 'Utils', `其他错误: ${error.code}`);
  }
}

// 显示提示信息
export function showPrompt(message: string): void {
  promptAction.showToast({
    message: message,
    duration: 2000
  });
}