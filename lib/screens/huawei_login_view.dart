/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef OnViewCreated = Function(HuaweiLoginViewController);

// 定义华为登录视图组件
class HuaweiLoginOhosView extends StatefulWidget {
  final OnViewCreated onViewCreated;
  final String viewTypeId;

  const HuaweiLoginOhosView(this.onViewCreated, this.viewTypeId, {Key? key})
      : super(key: key);

  @override
  State<HuaweiLoginOhosView> createState() => _HuaweiLoginOhosViewState();
}

class _HuaweiLoginOhosViewState extends State<HuaweiLoginOhosView> {
  @override
  Widget build(BuildContext context) {
    return OhosView(
      // viewType必须与Native端注册时指定的viewTypeId一致
      viewType: widget.viewTypeId,
      onPlatformViewCreated: (int id) {
        final channel = MethodChannel('${widget.viewTypeId}$id');
        final controller = HuaweiLoginViewController._(
          channel,
        );
        widget.onViewCreated(controller);
      },
      creationParams: const <String, dynamic>{},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}

// 实现Dart和Native端的交互
class HuaweiLoginViewController {
  final MethodChannel _channel;
  final StreamController<String> _controller = StreamController<String>();

  HuaweiLoginViewController._(
    this._channel,
  ) {
    _channel.setMethodCallHandler(
      (call) async {
        // 从Native端获取数据
        final result = call.arguments as String;
        final data = {
          'method': call.method,
          'data': result,
        };
        _controller.sink.add(jsonEncode(data));
      },
    );
  }

  Stream<String> get customDataStream => _controller.stream;

  // 发送数据到Native端
  Future<void> sendMessageToOhosView(String method, message) async {
    print('sendMessageToOhosView: $method ${message.toString()}');
    await _channel.invokeMethod(
      method,
      message,
    );
  }
}