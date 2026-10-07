#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#define CINTERFACE
#include <windows.h>
#include <sapi.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct VSpeechInputSystem {
    ISpRecognizer *recognizer;
    ISpRecoContext *context;
    ISpRecoGrammar *grammar;
    int co_initialized;
} VSpeechInputSystem;

static void vspeech_input_release_event(SPEVENT *event) {
    if (!event) return;
    if (event->elParamType == SPET_LPARAM_IS_OBJECT && event->lParam) {
        IUnknown_Release((IUnknown *)(uintptr_t)event->lParam);
    } else if (event->elParamType == SPET_LPARAM_IS_POINTER && event->lParam) {
        CoTaskMemFree((void *)(uintptr_t)event->lParam);
    }
    event->lParam = 0;
}

static int vspeech_input_wide_to_utf8(const wchar_t *input, char *output, int capacity) {
    if (!output || capacity <= 0) return 0;
    output[0] = 0;
    if (!input || !input[0]) return 0;
    int count = WideCharToMultiByte(CP_UTF8, 0, input, -1, output, capacity, NULL, NULL);
    if (count <= 0) {
        output[0] = 0;
        return 0;
    }
    output[capacity - 1] = 0;
    return 1;
}

void *vspeech_input_system_open(void) {
    HRESULT init = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    int co_initialized = SUCCEEDED(init) ? 1 : 0;
    if (FAILED(init) && init != RPC_E_CHANGED_MODE) {
        return NULL;
    }

    VSpeechInputSystem *state = (VSpeechInputSystem *)calloc(1, sizeof(VSpeechInputSystem));
    if (!state) {
        if (co_initialized) CoUninitialize();
        return NULL;
    }
    state->co_initialized = co_initialized;

    HRESULT hr = CoCreateInstance(&CLSID_SpSharedRecognizer, NULL, CLSCTX_ALL,
        &IID_ISpRecognizer, (void **)&state->recognizer);
    if (FAILED(hr) || !state->recognizer) goto fail;

    hr = ISpRecognizer_CreateRecoContext(state->recognizer, &state->context);
    if (FAILED(hr) || !state->context) goto fail;

    hr = ISpRecoContext_SetNotifyWin32Event(state->context);
    if (FAILED(hr)) goto fail;

    ULONGLONG interest = SPFEI(SPEI_HYPOTHESIS) | SPFEI(SPEI_RECOGNITION);
    hr = ISpRecoContext_SetInterest(state->context, interest, interest);
    if (FAILED(hr)) goto fail;

    hr = ISpRecoContext_CreateGrammar(state->context, 1, &state->grammar);
    if (FAILED(hr) || !state->grammar) goto fail;

    hr = ISpRecoGrammar_LoadDictation(state->grammar, NULL, SPLO_STATIC);
    if (FAILED(hr)) goto fail;

    hr = ISpRecoGrammar_SetDictationState(state->grammar, SPRS_ACTIVE);
    if (FAILED(hr)) goto fail;

    return state;

fail:
    if (state->grammar) ISpRecoGrammar_Release(state->grammar);
    if (state->context) ISpRecoContext_Release(state->context);
    if (state->recognizer) ISpRecognizer_Release(state->recognizer);
    if (state->co_initialized) CoUninitialize();
    free(state);
    return NULL;
}

int vspeech_input_system_poll(void *handle, char *text, int capacity, int *final) {
    VSpeechInputSystem *state = (VSpeechInputSystem *)handle;
    if (!state || !state->context || !text || capacity <= 0) return 0;
    text[0] = 0;
    if (final) *final = 0;

    for (int attempts = 0; attempts < 8; attempts++) {
        SPEVENT event;
        memset(&event, 0, sizeof(event));
        ULONG fetched = 0;
        HRESULT hr = ISpRecoContext_GetEvents(state->context, 1, &event, &fetched);
        if (FAILED(hr) || fetched == 0) return 0;

        if ((event.eEventId == SPEI_HYPOTHESIS || event.eEventId == SPEI_RECOGNITION)
            && event.lParam) {
            ISpRecoResult *result = (ISpRecoResult *)(uintptr_t)event.lParam;
            wchar_t *wide = NULL;
            BYTE display_attributes = 0;
            hr = ISpRecoResult_GetText(result, SP_GETWHOLEPHRASE, SP_GETWHOLEPHRASE,
                TRUE, &wide, &display_attributes);
            int ok = 0;
            if (SUCCEEDED(hr) && wide) {
                ok = vspeech_input_wide_to_utf8(wide, text, capacity);
                CoTaskMemFree(wide);
            }
            if (final) *final = event.eEventId == SPEI_RECOGNITION ? 1 : 0;
            vspeech_input_release_event(&event);
            if (ok && text[0]) return 1;
            continue;
        }

        vspeech_input_release_event(&event);
    }
    return 0;
}

void vspeech_input_system_close(void *handle) {
    VSpeechInputSystem *state = (VSpeechInputSystem *)handle;
    if (!state) return;
    if (state->grammar) {
        ISpRecoGrammar_SetDictationState(state->grammar, SPRS_INACTIVE);
        ISpRecoGrammar_Release(state->grammar);
    }
    if (state->context) ISpRecoContext_Release(state->context);
    if (state->recognizer) ISpRecognizer_Release(state->recognizer);
    if (state->co_initialized) CoUninitialize();
    free(state);
}
