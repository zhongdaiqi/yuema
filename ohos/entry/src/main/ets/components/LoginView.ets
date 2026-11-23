/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights reserved.
 */

import MethodChannel, { MethodCallHandler, } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import PlatformView, { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import common from '@ohos.app.ability.common';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import StandardMethodCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMethodCodec';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { loginComponentManager, LoginWithHuaweiIDButton } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { JSON } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MessageCodec,
  PlatformViewFactory,
  StandardMessageCodec
} from '@ohos/flutter_ohos';
import { AvoidRepeatClick, dealAllError, showNetWorkError, getUserProfile, HuaweiIDData } from '../common/Utils';
import { ErrorCode } from '../common/ErrorCodeEntity';
import { connection } from '@kit.NetworkKit';

// 定义登录组件管理器
@Entry
@Component
struct LoginView {
  @State message: string = 'Hello World'
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
        // 华为登录按钮
        LoginWithHuaweiIDButton({
          loginType: LoginType.QUICK_LOGIN,
          sizeType: ButtonSizeType.SMALL,
          theme: ButtonThemeType.DARK
        })
        .onClick(() => {
          this.handleHuaweiLogin();
        })
        .height(48)
        .width('80%')
      }
      .width('100%')
    }
    .height('100%')
  }

  // 处理华为登录
  private handleHuaweiLogin() {
    hilog.info(0x0000, 'LoginView', '开始华为登录流程');

    // 创建授权请求
    const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    // 配置scope以获取用户信息
    authRequest.scopes = ['quickLoginAnonymousPhone'];
    // 设置forceAuthorization为false以实现静默获取
    authRequest.forceAuthorization = false;

    const controller = new authentication.AuthenticationController();
    
    controller.executeRequest(authRequest).then((response: authentication.AuthorizationWithHuaweiIDResponse) => {
      hilog.info(0x0000, 'LoginView', '华为登录请求成功');
      
      if (response && response.data) {
        const data = response.data as HuaweiIDData;
        if (data && data.authorizationCode) {
          // 获取授权码成功，传递给Flutter端
          this.sendAuthCodeToFlutter(data.authorizationCode);
        } else {
          hilog.error(0x0000, 'LoginView', '未获取到授权码');
        }
      }
    }).catch((error: BusinessError) => {
      hilog.error(0x0000, 'LoginView', `华为登录失败: ${JSON.stringify(error)}`);
      // 处理错误
      this.handleLoginError(error);
    });
  }

  // 发送授权码到Flutter端
  private sendAuthCodeToFlutter(authCode: string) {
    // 这里需要通过MethodChannel将授权码发送到Flutter端
    hilog.info(0x0000, 'LoginView', `发送授权码到Flutter端: ${authCode.substring(0, 5)}...`);
  }

  // 处理登录错误
  private handleLoginError(error: BusinessError) {
    hilog.error(0x0000, 'LoginView', `登录错误: ${JSON.stringify(error)}`);
    
    // 根据错误码处理不同情况
    if (error.code === 1001502001) {
      // 用户未登录华为账号
      hilog.info(0x0000, 'LoginView', '用户未登录华为账号，需要展示其他登录方式');
    }
  }
}