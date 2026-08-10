#include <napi/native_api.h>

#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <unordered_set>
#include <vector>

#include <hilog/log.h>
#include <mindspore/context.h>
#include <mindspore/model.h>
#include <mindspore/tensor.h>

namespace {

constexpr const char *kModuleName = "nextn_super_resolution";
constexpr int kScale = 2;
constexpr int kInputSize = 156;
constexpr int kOutputSize = 284;
constexpr int kTileSize = 142;
constexpr int kPrepadding = 7;

struct UpscaleTask {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::vector<uint8_t> input;
    std::vector<uint8_t> output;
    std::string modelPath;
    std::string error;
    int width = 0;
    int height = 0;
    int stride = 0;
    uint64_t requestId = 0;
    int64_t modelLoadMs = 0;
    int64_t inferenceMs = 0;
    int tileCount = 0;
};

std::mutex gModelMutex;
OH_AI_ModelHandle gCachedModel = nullptr;
std::string gCachedModelPath;
std::mutex gRequestStateMutex;
std::unordered_set<uint64_t> gInactiveRequests;
std::mutex gInteractionMutex;
std::condition_variable gInteractionCondition;
bool gInteractionPaused = false;

using SteadyClock = std::chrono::steady_clock;

int64_t ElapsedMilliseconds(const SteadyClock::time_point &startedAt)
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        SteadyClock::now() - startedAt).count();
}

std::string GetString(napi_env env, napi_value value)
{
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) {
        return {};
    }
    std::string result(length + 1, '\0');
    size_t copied = 0;
    if (napi_get_value_string_utf8(env, value, result.data(), result.size(), &copied) != napi_ok) {
        return {};
    }
    result.resize(copied);
    return result;
}

bool GetBytes(napi_env env, napi_value value, std::vector<uint8_t> &bytes)
{
    bool isArrayBuffer = false;
    if (napi_is_arraybuffer(env, value, &isArrayBuffer) != napi_ok || !isArrayBuffer) {
        return false;
    }
    void *data = nullptr;
    size_t length = 0;
    if (napi_get_arraybuffer_info(env, value, &data, &length) != napi_ok || data == nullptr) {
        return false;
    }
    const auto *begin = static_cast<const uint8_t *>(data);
    bytes.assign(begin, begin + length);
    return true;
}

bool GetInt(napi_env env, napi_value value, int &result)
{
    int32_t number = 0;
    if (napi_get_value_int32(env, value, &number) != napi_ok) {
        return false;
    }
    result = number;
    return true;
}

bool GetInt64(napi_env env, napi_value value, int64_t &result)
{
    return napi_get_value_int64(env, value, &result) == napi_ok;
}

bool EnsureRequestActive(UpscaleTask &task)
{
    std::lock_guard<std::mutex> lock(gRequestStateMutex);
    if (gInactiveRequests.find(task.requestId) == gInactiveRequests.end()) {
        return true;
    }
    task.error = "reader enhancement request superseded";
    return false;
}

bool WaitUntilInferenceAllowed(UpscaleTask &task)
{
    while (true) {
        {
            std::unique_lock<std::mutex> lock(gInteractionMutex);
            if (!gInteractionPaused) {
                break;
            }
            gInteractionCondition.wait_for(lock, std::chrono::milliseconds(16));
        }
        if (!EnsureRequestActive(task)) {
            return false;
        }
    }
    return EnsureRequestActive(task);
}

void ResetCachedModel()
{
    if (gCachedModel != nullptr) {
        OH_AI_ModelDestroy(&gCachedModel);
    }
    gCachedModelPath.clear();
}

bool ValidateInput(UpscaleTask &task, OH_AI_TensorHandle input)
{
    const int64_t expectedElements = static_cast<int64_t>(kInputSize) * kInputSize * 3;
    const size_t expectedBytes = static_cast<size_t>(expectedElements) * sizeof(float);
    if (input == nullptr ||
        OH_AI_TensorGetDataType(input) != OH_AI_DATATYPE_NUMBERTYPE_FLOAT32 ||
        OH_AI_TensorGetFormat(input) != OH_AI_FORMAT_NCHW ||
        OH_AI_TensorGetElementNum(input) != expectedElements ||
        OH_AI_TensorGetDataSize(input) != expectedBytes) {
        task.error = "reader enhancement model has an unexpected input contract";
        return false;
    }
    return true;
}

void AddPreferredDevices(OH_AI_ContextHandle context)
{
    OH_AI_DeviceInfoHandle accelerator =
        OH_AI_CreateNNRTDeviceInfoByType(OH_AI_NNRTDEVICE_ACCELERATOR);
    if (accelerator != nullptr) {
        OH_AI_DeviceInfoSetPerformanceMode(accelerator, OH_AI_PERFORMANCE_HIGH);
        OH_AI_DeviceInfoSetPriority(accelerator, OH_AI_PRIORITY_LOW);
        OH_AI_ContextAddDeviceInfo(context, accelerator);
    }
    OH_AI_DeviceInfoHandle cpu = OH_AI_DeviceInfoCreate(OH_AI_DEVICETYPE_CPU);
    if (cpu != nullptr) {
        OH_AI_DeviceInfoSetEnableFP16(cpu, false);
        OH_AI_ContextAddDeviceInfo(context, cpu);
    }
}

OH_AI_ModelHandle PrepareModel(UpscaleTask &task)
{
    if (gCachedModel != nullptr && gCachedModelPath == task.modelPath) {
        task.modelLoadMs = 0;
        return gCachedModel;
    }
    OH_AI_ContextHandle context = OH_AI_ContextCreate();
    OH_AI_ModelHandle model = OH_AI_ModelCreate();
    if (context == nullptr || model == nullptr) {
        if (model != nullptr) {
            OH_AI_ModelDestroy(&model);
        }
        if (context != nullptr) {
            OH_AI_ContextDestroy(&context);
        }
        task.error = "failed to create reader enhancement runtime";
        return nullptr;
    }
    OH_AI_ContextSetThreadNum(context, 2);
    AddPreferredDevices(context);
    const SteadyClock::time_point startedAt = SteadyClock::now();
    const OH_AI_Status status = OH_AI_ModelBuildFromFile(
        model,
        task.modelPath.c_str(),
        OH_AI_MODELTYPE_MINDIR,
        context);
    task.modelLoadMs = ElapsedMilliseconds(startedAt);
    OH_AI_ContextDestroy(&context);
    if (status != OH_AI_STATUS_SUCCESS) {
        OH_AI_ModelDestroy(&model);
        task.error = "failed to build reader enhancement model";
        return nullptr;
    }
    const OH_AI_TensorHandleArray inputs = OH_AI_ModelGetInputs(model);
    if (inputs.handle_num != 1 || inputs.handle_list == nullptr ||
        !ValidateInput(task, inputs.handle_list[0])) {
        OH_AI_ModelDestroy(&model);
        return nullptr;
    }
    ResetCachedModel();
    gCachedModel = model;
    gCachedModelPath = task.modelPath;
    return gCachedModel;
}

uint8_t ToByte(float value)
{
    return static_cast<uint8_t>(std::clamp(value * 255.0f + 0.5f, 0.0f, 255.0f));
}

void PrepareTile(const UpscaleTask &task, int inputX, int inputY, std::vector<float> &tile)
{
    const size_t plane = static_cast<size_t>(kInputSize) * kInputSize;
    tile.resize(plane * 3);
    constexpr float inverseByte = 1.0f / 255.0f;
    for (int y = 0; y < kInputSize; ++y) {
        const int sourceY = std::clamp(inputY + y - kPrepadding, 0, task.height - 1);
        for (int x = 0; x < kInputSize; ++x) {
            const int sourceX = std::clamp(inputX + x - kPrepadding, 0, task.width - 1);
            const size_t pixel = static_cast<size_t>(sourceY) * task.stride + sourceX * 4;
            const size_t destination = static_cast<size_t>(y) * kInputSize + x;
            tile[destination] = task.input[pixel] * inverseByte;
            tile[plane + destination] = task.input[pixel + 1] * inverseByte;
            tile[plane * 2 + destination] = task.input[pixel + 2] * inverseByte;
        }
    }
}

bool WriteTile(
    UpscaleTask &task,
    const float *tensor,
    int inputX,
    int inputY,
    int tileWidth,
    int tileHeight)
{
    if (tensor == nullptr) {
        task.error = "reader enhancement output is unavailable";
        return false;
    }
    const size_t plane = static_cast<size_t>(kOutputSize) * kOutputSize;
    const int outputWidth = task.width * kScale;
    const int writeWidth = tileWidth * kScale;
    const int writeHeight = tileHeight * kScale;
    const int outputX = inputX * kScale;
    const int outputY = inputY * kScale;
    for (int y = 0; y < writeHeight; ++y) {
        for (int x = 0; x < writeWidth; ++x) {
            const size_t tensorOffset = static_cast<size_t>(y) * kOutputSize + x;
            const size_t destination =
                (static_cast<size_t>(outputY + y) * outputWidth + outputX + x) * 4;
            task.output[destination] = ToByte(tensor[tensorOffset]);
            task.output[destination + 1] = ToByte(tensor[plane + tensorOffset]);
            task.output[destination + 2] = ToByte(tensor[plane * 2 + tensorOffset]);
            task.output[destination + 3] = 255;
        }
    }
    return true;
}

bool ValidateTask(UpscaleTask &task)
{
    if (task.width <= 0 || task.height <= 0 || task.stride < task.width * 4) {
        task.error = "invalid reader enhancement image dimensions";
        return false;
    }
    const size_t required = static_cast<size_t>(task.stride) * task.height;
    if (task.input.size() < required) {
        task.error = "reader enhancement image buffer is incomplete";
        return false;
    }
    const int outputWidth = task.width * kScale;
    const int outputHeight = task.height * kScale;
    if (outputWidth <= 0 || outputHeight <= 0 ||
        static_cast<size_t>(outputWidth) > SIZE_MAX / static_cast<size_t>(outputHeight) / 4) {
        task.error = "reader enhancement output dimensions are unsupported";
        return false;
    }
    return true;
}

bool RunUpscale(UpscaleTask &task)
{
    if (!ValidateTask(task)) {
        return false;
    }
    std::lock_guard<std::mutex> lock(gModelMutex);
    OH_AI_ModelHandle model = PrepareModel(task);
    if (model == nullptr) {
        return false;
    }
    const OH_AI_TensorHandleArray inputs = OH_AI_ModelGetInputs(model);
    if (inputs.handle_num != 1 || inputs.handle_list == nullptr ||
        !ValidateInput(task, inputs.handle_list[0])) {
        return false;
    }
    const int outputWidth = task.width * kScale;
    const int outputHeight = task.height * kScale;
    task.output.assign(static_cast<size_t>(outputWidth) * outputHeight * 4, 255);
    std::vector<float> tile;
    for (int inputY = 0; inputY < task.height; inputY += kTileSize) {
        const int tileHeight = std::min(kTileSize, task.height - inputY);
        for (int inputX = 0; inputX < task.width; inputX += kTileSize) {
            if (!WaitUntilInferenceAllowed(task)) {
                return false;
            }
            const int tileWidth = std::min(kTileSize, task.width - inputX);
            PrepareTile(task, inputX, inputY, tile);
            void *inputData = OH_AI_TensorGetMutableData(inputs.handle_list[0]);
            if (inputData == nullptr) {
                task.error = "reader enhancement input buffer is unavailable";
                return false;
            }
            std::memcpy(inputData, tile.data(), tile.size() * sizeof(float));
            OH_AI_TensorHandleArray outputs = {0, nullptr};
            const SteadyClock::time_point startedAt = SteadyClock::now();
            const OH_AI_Status status = OH_AI_ModelPredict(model, inputs, &outputs, nullptr, nullptr);
            task.inferenceMs += ElapsedMilliseconds(startedAt);
            const int64_t expectedElements = static_cast<int64_t>(kOutputSize) * kOutputSize * 3;
            if (status != OH_AI_STATUS_SUCCESS || outputs.handle_num != 1 || outputs.handle_list == nullptr ||
                outputs.handle_list[0] == nullptr ||
                OH_AI_TensorGetDataType(outputs.handle_list[0]) != OH_AI_DATATYPE_NUMBERTYPE_FLOAT32 ||
                OH_AI_TensorGetFormat(outputs.handle_list[0]) != OH_AI_FORMAT_NCHW ||
                OH_AI_TensorGetElementNum(outputs.handle_list[0]) != expectedElements) {
                task.error = "reader enhancement model returned an unexpected output contract";
                return false;
            }
            const auto *output = static_cast<const float *>(OH_AI_TensorGetData(outputs.handle_list[0]));
            if (!WriteTile(task, output, inputX, inputY, tileWidth, tileHeight)) {
                return false;
            }
            task.tileCount += 1;
        }
    }
    return true;
}

void ExecuteUpscale(napi_env env, void *data)
{
    (void)env;
    auto *task = static_cast<UpscaleTask *>(data);
    RunUpscale(*task);
    std::vector<uint8_t>().swap(task->input);
}

void ExecutePrepare(napi_env env, void *data)
{
    (void)env;
    auto *task = static_cast<UpscaleTask *>(data);
    std::lock_guard<std::mutex> lock(gModelMutex);
    PrepareModel(*task);
}

napi_value StringValue(napi_env env, const char *value)
{
    napi_value result = nullptr;
    napi_create_string_utf8(env, value, NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value Int64Value(napi_env env, int64_t value)
{
    napi_value result = nullptr;
    napi_create_int64(env, value, &result);
    return result;
}

void FinalizeOutputBuffer(napi_env env, void *data, void *hint)
{
    (void)env;
    (void)data;
    delete static_cast<std::vector<uint8_t> *>(hint);
}

void CompleteUpscale(napi_env env, napi_status status, void *data)
{
    auto *task = static_cast<UpscaleTask *>(data);
    if (status == napi_ok && task->error.empty()) {
        napi_value result = nullptr;
        napi_value outputBuffer = nullptr;
        auto *output = new std::vector<uint8_t>(std::move(task->output));
        if (napi_create_object(env, &result) == napi_ok &&
            napi_create_external_arraybuffer(
                env,
                output->data(),
                output->size(),
                FinalizeOutputBuffer,
                output,
                &outputBuffer) == napi_ok) {
            napi_set_named_property(env, result, "pixels", outputBuffer);
            napi_set_named_property(env, result, "backend", StringValue(env, "mindspore"));
            napi_set_named_property(env, result, "modelLoadMs", Int64Value(env, task->modelLoadMs));
            napi_set_named_property(env, result, "inferenceMs", Int64Value(env, task->inferenceMs));
            napi_set_named_property(env, result, "tileCount", Int64Value(env, task->tileCount));
            napi_resolve_deferred(env, task->deferred, result);
        } else {
            delete output;
            task->error = "failed to allocate reader enhancement output";
        }
    }
    if (status != napi_ok || !task->error.empty()) {
        napi_value text = nullptr;
        napi_value error = nullptr;
        const char *message = task->error.empty() ? "reader enhancement failed" : task->error.c_str();
        napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text);
        napi_create_error(env, nullptr, text, &error);
        napi_reject_deferred(env, task->deferred, error);
    }
    napi_delete_async_work(env, task->work);
    {
        std::lock_guard<std::mutex> lock(gRequestStateMutex);
        gInactiveRequests.erase(task->requestId);
    }
    delete task;
}

void CompletePrepare(napi_env env, napi_status status, void *data)
{
    auto *task = static_cast<UpscaleTask *>(data);
    if (status == napi_ok && task->error.empty()) {
        napi_value result = nullptr;
        if (napi_create_object(env, &result) == napi_ok) {
            napi_set_named_property(env, result, "backend", StringValue(env, "mindspore"));
            napi_set_named_property(env, result, "modelLoadMs", Int64Value(env, task->modelLoadMs));
            napi_resolve_deferred(env, task->deferred, result);
        } else {
            task->error = "failed to allocate reader enhancement preparation result";
        }
    }
    if (status != napi_ok || !task->error.empty()) {
        napi_value text = nullptr;
        napi_value error = nullptr;
        const char *message = task->error.empty() ? "reader enhancement preparation failed" : task->error.c_str();
        napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text);
        napi_create_error(env, nullptr, text, &error);
        napi_reject_deferred(env, task->deferred, error);
    }
    napi_delete_async_work(env, task->work);
    delete task;
}

napi_value PrepareModelNapi(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr) != napi_ok || argc < 1) {
        napi_throw_type_error(env, nullptr, "prepareModel expects a model path");
        return nullptr;
    }
    auto *task = new UpscaleTask();
    task->modelPath = GetString(env, argv[0]);
    if (task->modelPath.empty()) {
        delete task;
        napi_throw_type_error(env, nullptr, "reader enhancement model path is required");
        return nullptr;
    }
    napi_value promise = nullptr;
    napi_create_promise(env, &task->deferred, &promise);
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "NextNReaderEnhancementPrepare", NAPI_AUTO_LENGTH, &resourceName);
    if (napi_create_async_work(env, nullptr, resourceName, ExecutePrepare, CompletePrepare, task, &task->work) != napi_ok ||
        napi_queue_async_work_with_qos(env, task->work, napi_qos_background) != napi_ok) {
        if (task->work != nullptr) {
            napi_delete_async_work(env, task->work);
        }
        delete task;
        napi_throw_error(env, nullptr, "failed to queue reader enhancement preparation");
        return nullptr;
    }
    return promise;
}

napi_value UpscaleRgba(napi_env env, napi_callback_info info)
{
    size_t argc = 6;
    napi_value argv[6] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr) != napi_ok || argc < 6) {
        napi_throw_type_error(env, nullptr, "upscaleRgba expects six arguments");
        return nullptr;
    }
    auto *task = new UpscaleTask();
    int64_t requestId = 0;
    if (!GetBytes(env, argv[0], task->input) ||
        !GetInt(env, argv[1], task->width) ||
        !GetInt(env, argv[2], task->height) ||
        !GetInt(env, argv[3], task->stride) ||
        !GetInt64(env, argv[5], requestId) || requestId <= 0) {
        delete task;
        napi_throw_type_error(env, nullptr, "invalid reader enhancement arguments");
        return nullptr;
    }
    task->modelPath = GetString(env, argv[4]);
    task->requestId = static_cast<uint64_t>(requestId);
    if (task->modelPath.empty()) {
        delete task;
        napi_throw_type_error(env, nullptr, "reader enhancement model path is required");
        return nullptr;
    }
    napi_value promise = nullptr;
    napi_create_promise(env, &task->deferred, &promise);
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "NextNReaderEnhancement", NAPI_AUTO_LENGTH, &resourceName);
    if (napi_create_async_work(env, nullptr, resourceName, ExecuteUpscale, CompleteUpscale, task, &task->work) != napi_ok ||
        napi_queue_async_work_with_qos(env, task->work, napi_qos_background) != napi_ok) {
        if (task->work != nullptr) {
            napi_delete_async_work(env, task->work);
        }
        delete task;
        napi_throw_error(env, nullptr, "failed to queue reader enhancement");
        return nullptr;
    }
    return promise;
}

napi_value SetRequestActive(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2] = {nullptr};
    int64_t requestId = 0;
    bool active = false;
    if (napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr) != napi_ok || argc < 2 ||
        !GetInt64(env, argv[0], requestId) || requestId <= 0 ||
        napi_get_value_bool(env, argv[1], &active) != napi_ok) {
        napi_throw_type_error(env, nullptr, "setRequestActive expects a request ID and state");
        return nullptr;
    }
    {
        std::lock_guard<std::mutex> lock(gRequestStateMutex);
        if (active) {
            gInactiveRequests.erase(static_cast<uint64_t>(requestId));
        } else {
            gInactiveRequests.insert(static_cast<uint64_t>(requestId));
        }
    }
    if (!active) {
        gInteractionCondition.notify_all();
    }
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetInteractionPaused(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    bool paused = false;
    if (napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr) != napi_ok || argc < 1 ||
        napi_get_value_bool(env, argv[0], &paused) != napi_ok) {
        napi_throw_type_error(env, nullptr, "setInteractionPaused expects a boolean state");
        return nullptr;
    }
    {
        std::lock_guard<std::mutex> lock(gInteractionMutex);
        gInteractionPaused = paused;
    }
    if (!paused) {
        gInteractionCondition.notify_all();
    }
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor descriptors[] = {
        {"prepareModel", nullptr, PrepareModelNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"upscaleRgba", nullptr, UpscaleRgba, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setRequestActive", nullptr, SetRequestActive, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setInteractionPaused", nullptr, SetInteractionPaused, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
    return exports;
}
EXTERN_C_END

static napi_module readerEnhancementModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = kModuleName,
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterNextNReaderEnhancementModule(void)
{
    napi_module_register(&readerEnhancementModule);
}
