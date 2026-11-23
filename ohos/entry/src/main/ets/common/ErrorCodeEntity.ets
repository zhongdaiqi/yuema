/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights reserved.
 */

// 错误码定义
export class ErrorCode {
  // 华为账号登录相关错误码
  static readonly HUAWEI_ACCOUNT_NOT_LOGIN = 1001502001;  // 用户未登录华为账号
  static readonly HUAWEI_ACCOUNT_CANCEL_AUTH = 1001502002; // 用户取消授权
  static readonly HUAWEI_ACCOUNT_INVALID_TOKEN = 1001502003; // 令牌无效
  static readonly HUAWEI_ACCOUNT_NETWORK_ERROR = 1001502004; // 网络错误
  static readonly HUAWEI_ACCOUNT_SERVER_ERROR = 1001502005; // 服务器错误
  static readonly HUAWEI_ACCOUNT_PARAM_ERROR = 1001502006; // 参数错误
  static readonly HUAWEI_ACCOUNT_PERMISSION_DENIED = 1001502007; // 权限被拒绝
  static readonly HUAWEI_ACCOUNT_USER_CANCEL = 1001502008; // 用户取消操作
  static readonly HUAWEI_ACCOUNT_TIMEOUT = 1001502009; // 操作超时
  static readonly HUAWEI_ACCOUNT_UNKNOWN_ERROR = 1001502999; // 未知错误
}