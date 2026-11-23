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

const logTag: string = 'HuaweiLoginView';
const domainId: number = 0x0000;

// 初始化全局存储值
AppStorage.SetOrCreate('shouldTriggerLogin', false);

// Define the one-tap sign-in component.
@Component
struct HuaweiLoginButtonComponent {
  @StorageLink('agreementStatus') @Watch('watchAgreementStatus') agreementStatus: boolean = false;
  @StorageLink('reOpenDialog') @Watch('reOpenDialogChange') reOpenDialog: boolean = false;
  @StorageLink('shouldTriggerLogin') @Watch('watchTriggerLogin') shouldTriggerLogin: boolean = false;  // 添加这个监听
  @StorageLink('loginLoading') loading: boolean = false;
  @Prop params: Params;
  private privacyText: loginComponentManager.PrivacyText[] = [
    {
      text: '同意',
      type: loginComponentManager.TextType.PLAIN_TEXT
    }, {
    text: '用户协议',
    type: loginComponentManager.TextType.RICH_TEXT
  }, {
    text: '、',
    type: loginComponentManager.TextType.PLAIN_TEXT
  }, {
    text: '隐私政策',
    type: loginComponentManager.TextType.RICH_TEXT
  }, {
    text: '、',
    type: loginComponentManager.TextType.PLAIN_TEXT
  }, {
    text: '和',
    type: loginComponentManager.TextType.PLAIN_TEXT
  }, {
    text: '华为账号用户认证协议',
    type: loginComponentManager.TextType.RICH_TEXT,
    tag: 'tag'
  }, {
    text: '。',
    type: loginComponentManager.TextType.PLAIN_TEXT
  }
  ];
  customView: CustomView = this.params?.platformView as CustomView;
  agreementDialog: CustomDialogController = new CustomDialogController({
    builder: AgreementDialog({
      privacyText: this.privacyText,
      cancel: () => {
        this.agreementDialog.close();
      },
      confirm: () => {
        this.agreementDialog.close();
        this.customView.sendMessage('AgreementStatusChanged', '1');
        this.customView.sendMessage('loginStart', '');
        this.loading = true;
        this.agreementStatus = true;
        // Set the agreement status to ACCEPTED.
        this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.ACCEPTED);
        /*
         * Call this method to complete accepting the agreements and signing in at the same time.
         * There is no need to tap the sign-in button again.
         * */
        this.controller.continueLogin((error: BusinessError) => {
          if (error) {
            hilog.error(domainId, logTag,
              `Failed to login with agreementDialog. errCode is ${error.code}, message is ${error.message}`);
          } else {
            hilog.info(domainId, logTag, 'Succeeded in clicking agreementDialog continueLogin.');
            // After the sign-in is successful, the server processes the response result.
            // ...
          }
        });
      },
      openDialog: () => {
        this.agreementDialog.open();
      },
      closeDialog: () => {
        this.agreementDialog.close();

      },
      jumpToPrivacyWebView: () => {
        this.customView.sendMessage('openPrivacy', '');
        this.agreementDialog.close();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
  });

  aboutToAppear() {
    // 组件即将出现时，重置状态为初始状态
    this.agreementStatus = false;
    this.shouldTriggerLogin = false;
    this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED);
  }

  watchAgreementStatus(): void {
    hilog.info(domainId, logTag, `this.agreementStatus is ${this.agreementStatus}`);
    if (this.agreementStatus) {
      this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.ACCEPTED);
    } else {
      this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED);
    }
    // 发送协议状态变更确认消息
    this.customView.sendMessage('AgreementStatusChangedAck', this.agreementStatus ? '1' : '0');
  }

  watchTriggerLogin(): void {
    // 当shouldTriggerLogin变为true时，执行登录操作
    if (this.shouldTriggerLogin) {
      hilog.info(domainId, logTag, 'Triggering login from Flutter message');
      // 重置标志
      AppStorage.SetOrCreate('shouldTriggerLogin', false);
      
      // 检查协议状态，如果已同意则执行登录
      if (this.agreementStatus) {
        this.customView.sendMessage('loginStart', '');
        this.loading = true;
        this.controller.continueLogin((error: BusinessError) => {
          if (error) {
            hilog.error(domainId, logTag,
              `Failed to login from Flutter trigger. errCode is ${error.code}, message is ${error.message}`);
          } else {
            hilog.info(domainId, logTag, 'Succeeded in login from Flutter trigger.');
          }
        });
      } else {
        // 如果协议未同意，发送错误消息
        this.customView.sendMessage('loginError', JSON.stringify({
          code: 1005300001,
          message: 'the user did not accept the agreement.'
        }));
      }
    }
  }

  reOpenDialogChange() {
    if (this.reOpenDialog) {
      this.agreementDialog.open();
      this.reOpenDialog = false;
    }
  }

  controller = new loginComponentManager.LoginWithHuaweiIDButtonController()
    .setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED)
    .onClickEvent(() => {
      this.customView.sendMessage('loginStart', '');
      this.loading = true;
    })
    .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential) => {
      this.customView.sendMessage('loginEnd', '');
      this.loading = false;
      // Process the sign-in result.
      if (error) {
        hilog.error(domainId, logTag, `Login error: code=${error.code}, message=${error.message}`);
        // Send error to Dart side
        this.customView.sendMessage('loginError', JSON.stringify({
          code: error.code,
          message: error.message
        }));
        // 登录失败后重置协议状态，确保下次尝试时状态正确
        this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED);
        AppStorage.SetOrCreate('agreementStatus', false);
        return;
      }
      // Obtain sign-in information.
      const authCode = response.authorizationCode;

      // Send data to the Dart side. Encrypt sensitive data in your actual development.
      this.customView.sendMessage('loginSuccess', authCode); // 直接发送authCode字符串
    });

  build() {
    LoginWithHuaweiIDButton({
      params: {
        // Custom button style.
        style: loginComponentManager.Style.BUTTON_CUSTOM,
        extraStyle: {
          buttonStyle: new loginComponentManager.ButtonStyle()
        },
        loginType: loginComponentManager.LoginType.QUICK_LOGIN,
        supportDarkMode: true
      },
      controller: this.controller
    }).id('login_with_huaweiId_button')
  }
}

// Define the builder method and add the one-tap sign-in component to the builder method.
@Builder
function HuaweiLoginButtonBuilder(params: Params) {
  HuaweiLoginButtonComponent({ params: params })
}

// Extend PlatformView to implement a custom view, implement the getView API, and return WrappedBuilder (ButtonBuilder) through getView.
@Observed
class CustomView extends PlatformView implements MethodCallHandler {
  methodChannel: MethodChannel;
  context?: common.Context;
  args?: Object;

  constructor(context: common.Context, viewId: number, args: Object, message: BinaryMessenger) {
    super();
    this.context = context;
    this.args = args;
    // Register the message channel.
    this.methodChannel =
      new MethodChannel(message, `com.zuime.yuema/loginView${viewId}`, StandardMethodCodec.INSTANCE);
    this.methodChannel.setMethodCallHandler(this);
  }

  onMethodCall(call: MethodCall): void {
    // Receive messages from the Dart side.
    let method: string = call.method;
    hilog.info(domainId, logTag, method);
    switch (method) {
      case 'AgreementStatusChanged': {
        let value: boolean = call.args;
        let link: SubscribedAbstractProperty<boolean> = AppStorage.link('agreementStatus');
        link.set(value);
        break;
      }

      case 'openPrivacy': {
        this.sendMessage('openPrivacy', '0');
        break;
      }

      case 'reOpenDialog': {
        const link: SubscribedAbstractProperty<boolean> = AppStorage.link('reOpenDialog');
        link.set(true);
        break;
      }

      case 'login': {
        // 设置登录标志，让UI组件执行登录
        AppStorage.SetOrCreate('shouldTriggerLogin', true);
        break;
      }

      default: {
        // Unprocessed messages.
        break;
      }
    }
  }

  public sendMessage = (method: string, data: string) => {
    // Send messages to the Dart side.
    hilog.info(domainId, logTag, `method = ${method}`);
    this.methodChannel.invokeMethod(method, data);
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(HuaweiLoginButtonBuilder);
  }

  dispose(): void {
  }
}

// Implement PlatformViewFactory and create a CustomView instance in the create method.
class HuaweiLoginFactory extends PlatformViewFactory {
  message: BinaryMessenger;

  constructor(message: BinaryMessenger, createArgsCodes: MessageCodec<Object>) {
    super(createArgsCodes);
    this.message = message;
  }

  public create(context: common.Context, viewId: number, args: Object): PlatformView {
    return new CustomView(context, viewId, args, this.message);
  }
}

// Create a plugin that extends FlutterPlugin and register CustomFactory in onAttachedToEngine.
export default class HuaweiLoginPlugin implements FlutterPlugin {
  getUniqueClassName(): string {
    return 'HuaweiLoginPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    const registry = binding.getPlatformViewRegistry();
    if (registry) {
      registry.registerViewFactory('com.zuime.yuema/loginView', new HuaweiLoginFactory(binding.getBinaryMessenger(),
        StandardMessageCodec.INSTANCE));
    }
  }

  onDetachedFromEngine(): void {
  }
}

@CustomDialog
struct AgreementDialog {
  dialogController?: CustomDialogController;
  cancel: () => void = () => {
  };
  confirm: () => void = () => {
  };
  openDialog: () => void = () => {
  };
  closeDialog: () => void = () => {
  };
  jumpToPrivacyWebView: () => void = () => {
  };
  privacyText: loginComponentManager.PrivacyText[] = [];

  build() {
    Column() {
      Row() {
        Text('用户协议和隐私政策')
          .id('loginPanel_agreement_dialog_privacy_title')
          .maxFontSize(20)
          .minFontSize(16)
          .fontColor('#182431')
          .fontFamily('HarmonyOS Sans Medium')
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(2)
      }
      .alignItems(VerticalAlign.Center)
      .constraintSize({ minHeight: 56, maxWidth: 400 })
      .margin({
        left: 24,
        right: 24
      })

      Row() {
        Text() {
          if (this.privacyText && this.privacyText.length > 0) {
            ForEach(this.privacyText, (item: loginComponentManager.PrivacyText) => {
              if (item?.type === loginComponentManager.TextType.PLAIN_TEXT && item?.text) {
                Span(item?.text)
                  .fontSize(16)
                  .fontColor('#182431')
                  .fontFamily('HarmonyOS Sans Regular')
                  .fontWeight(FontWeight.Regular)
              } else if (item?.type === loginComponentManager.TextType.RICH_TEXT && item?.text) {
                Span(item?.text)
                  .fontSize(16)
                  .fontColor('#007DFF')
                  .fontFamily('HarmonyOS Sans Medium')
                  .fontWeight(FontWeight.Medium)
                  .focusable(true)
                  .focusOnTouch(true)
                  .id('protocolUrlToPrivacyWebViewSpan')
                  .onClick(() => {
                    hilog.info(domainId, logTag, 'protocol url click');
                  })
              }
            }, (item: loginComponentManager.PrivacyText, index: number): string => {
              return `${item.text}_${index}`;
            })
          }
        }
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(10)
        .textAlign(TextAlign.Start)
        .focusable(true)
        .focusOnTouch(true)
      }
      .width('100%')
      .padding({
        left: 24,
        right: 24
      })

      Flex({
        direction: FlexDirection.Row
      }) {
        Button('取消',
          { type: ButtonType.Capsule, stateEffect: true })
          .id('loginPanel_agreement_cancel_btn')
          .fontColor('#182431')
          .fontSize(16)
          .fontFamily('HarmonyOS Sans Medium')
          .backgroundColor(Color.Transparent)
          .fontWeight(FontWeight.Medium)
          .focusable(true)
          .focusOnTouch(true)
          .margin({ right: 8 })
          .width('50%')
          .constraintSize({ minHeight: 40, maxWidth: 400 })
          .id('cancelAgreementDialogButton')
          .onClick(() => {
            hilog.info(domainId, logTag, 'AgreementDialog cancel');
          })

        Button('同意并登录',
          { type: ButtonType.Capsule, stateEffect: true })
          .id('loginPanel_agreement_dialog_huawei_id_login_btn')
          .fontColor(Color.White)
          .backgroundColor('#007DFF')
          .fontSize(16)
          .fontFamily('HarmonyOS Sans Medium')
          .fontWeight(FontWeight.Medium)
          .focusable(true)
          .focusOnTouch(true)
          .margin({ left: 8 })
          .width('50%')
          .constraintSize({ minHeight: 40, maxWidth: 400 })
          .id('agreeAndSignInButton')
          .onClick(() => {
            hilog.info(domainId, logTag, 'AgreementDialog confirm');
          })
      }
      .margin({
        top: 8,
        left: 24,
        right: 24,
        bottom: 16
      })
    }.backgroundColor('#FFFFFF')
  }
}