#import "LeospluginPlugin.h"
#include <pthread.h>
#include <unistd.h>
#include <fstream>
#include <iostream>
#include <queue>
#include <sstream>
#include <string>

#ifdef CONTRIB_PATH
#include "tensorflow/contrib/lite/kernels/register.h"
#include "tensorflow/contrib/lite/model.h"
#include "tensorflow/contrib/lite/string_util.h"
#include "tensorflow/contrib/lite/op_resolver.h"
#else
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"
#include "tensorflow/lite/string_util.h"
#include "tensorflow/lite/op_resolver.h"
#endif

#include "ios_image_load.h"

#define LOG(x) std::cerr

@implementation LeospluginPlugin {
  NSObject<FlutterPluginRegistrar>* _registrar;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"leosplugin"
            binaryMessenger:[registrar messenger]];
  TflitePlugin* instance = [[TflitePlugin alloc] initWithRegistrar:registrar];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  self = [super init];
  if (self) {
    _registrar = registrar;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"loadModel" isEqualToString:call.method]) {
    NSString* load_result = loadModel(_registrar, call.arguments);
    result(load_result);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end

std::vector<std::string> labels;
std::unique_ptr<tflite::FlatBufferModel> model;
std::unique_ptr<tflite::Interpreter> interpreter;
bool interpreter_busy = false;

NSString* loadModel(NSObject<FlutterPluginRegistrar>* _registrar, NSDictionary* args) {
  NSString* key = [_registrar lookupKeyForAsset:args[@"model"]];
  NSString* graph_path = [[NSBundle mainBundle] pathForResource:key ofType:nil];
  const int num_threads = [args[@"numThreads"] intValue];
  
  model = tflite::FlatBufferModel::BuildFromFile([graph_path UTF8String]);
  if (!model) {
    return [NSString stringWithFormat:@"%s %@", "Failed to mmap model", graph_path];
  }
  LOG(INFO) << "Loaded model " << graph_path;
  model->error_reporter();
  LOG(INFO) << "resolved reporter";
  
  if ([args[@"labels"] length] > 0) {
    key = [_registrar lookupKeyForAsset:args[@"labels"]];
    NSString* labels_path = [[NSBundle mainBundle] pathForResource:key ofType:nil];
    LoadLabels(labels_path, &labels);
  }
  
  tflite::ops::builtin::BuiltinOpResolver resolver;
  tflite::InterpreterBuilder(*model, resolver)(&interpreter);
  if (!interpreter) {
    return @"Failed to construct interpreter";
  }
  
  if (interpreter->AllocateTensors() != kTfLiteOk) {
    return @"Failed to allocate tensors!";
  }
  
  if (num_threads != -1) {
    interpreter->SetNumThreads(num_threads);
  }
  return @"success";
}

void close() {
      interpreter.release();
      interpreter = NULL;
      model = NULL;
      labels.clear();
}