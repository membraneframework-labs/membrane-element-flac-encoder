#include "encoder.h"

static FLAC__StreamEncoderWriteStatus
handle_encoded(const FLAC__StreamEncoder *encoder, const FLAC__byte buffer[],
               size_t bytes, unsigned samples, unsigned current_frame,
               void *client_data);

void handle_destroy_state(UnifexEnv *env, UnifexNifState *state) {
  UNIFEX_UNUSED(env);
  FLAC__stream_encoder_delete(state->encoder);
}

UNIFEX_TERM create(UnifexEnv *env, UnifexPid pid, unsigned sample_rate,
                   unsigned sample_size, unsigned channels,
                   int compression_level, int verify) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);
  state->pid = pid;
  state->sample_size = sample_size;
  state->channels = channels;
  state->encoder = FLAC__stream_encoder_new();
  FLAC__StreamEncoder *encoder = state->encoder;
  if (!encoder) {
    result = create_result_error(env, "create_encoder");
    goto create_exit;
  }

  if (!FLAC__stream_encoder_set_sample_rate(encoder, sample_rate) ||
      !FLAC__stream_encoder_set_bits_per_sample(encoder, sample_size) ||
      !FLAC__stream_encoder_set_channels(encoder, channels) ||
      !FLAC__stream_encoder_set_compression_level(encoder, compression_level) ||
      !FLAC__stream_encoder_set_verify(encoder, verify)) {
    MEMBRANE_WARN(env, "Cannot set encoder params. Encoder state: %s\n",
                  FLAC__StreamEncoderStateString[FLAC__stream_encoder_get_state(
                      encoder)]);
    result = create_result_error(env, "set_encoder_params");
    goto create_exit;
  }

  FLAC__StreamEncoderInitStatus init_status = FLAC__stream_encoder_init_stream(
      encoder, handle_encoded, NULL, NULL, NULL, state);
  if (init_status != FLAC__STREAM_ENCODER_INIT_STATUS_OK) {
    MEMBRANE_WARN(env, "ERROR: initializing encoder: %s\n",
                  FLAC__StreamEncoderInitStatusString[init_status]);

    result = create_result_error(env, "init_encoder");
    goto create_exit;
  }

  result = create_result_ok(env, state);

create_exit:
  unifex_release_state(env, state);
  return result;
}

UNIFEX_TERM encode(UnifexEnv *env, UnifexPayload *buffer, State *state) {
  UNIFEX_TERM result;

  unsigned samples = buffer->size / (state->sample_size / 8);
  FLAC__int32 *transformed = malloc(samples * sizeof(FLAC__int32));

  switch (state->sample_size) {
  case 8:
    for (unsigned i = 0; i < samples; i++) {
      transformed[i] = (FLAC__int32)(((int8_t *)buffer->data)[i]);
    }
    break;
  case 16:
    for (unsigned i = 0; i < samples; i++) {
      transformed[i] = (FLAC__int32)(((int16_t *)buffer->data)[i]);
    }
    break;
  case 24:
    for (unsigned i = 0; i < samples; i++) {
      transformed[i] = (FLAC__int32)(((uint16_t *)buffer->data)[i]);
      transformed[i] |= (FLAC__int32)(((int8_t *)buffer->data)[i]) << 16;
    }
    break;
  }

  if (FLAC__stream_encoder_process_interleaved(state->encoder, transformed,
                                               samples / state->channels)) {
    result = encode_result_ok(env);
  } else {
    MEMBRANE_WARN(env, "ERROR: encoder process: %s\n",
                  FLAC__StreamEncoderStateString[FLAC__stream_encoder_get_state(
                      state->encoder)]);
    result = encode_result_error(env, "encoder_process");
  }

  free(transformed);
  return result;
}

UNIFEX_TERM flush(UnifexEnv *env, State *state) {
  if (FLAC__stream_encoder_finish(state->encoder)) {
    return encode_result_ok(env);
  } else {
    MEMBRANE_WARN(env, "ERROR: encoder finish: %s\n",
                  FLAC__StreamEncoderStateString[FLAC__stream_encoder_get_state(
                      state->encoder)]);
    return encode_result_error(env, "encoder_process");
  }
}

static FLAC__StreamEncoderWriteStatus
handle_encoded(const FLAC__StreamEncoder *_encoder, const FLAC__byte buffer[],
               size_t bytes, unsigned _samples, unsigned _current_frame,
               void *client_data) {
  UNIFEX_UNUSED(_encoder);
  UNIFEX_UNUSED(_samples);
  UNIFEX_UNUSED(_current_frame);
  FLAC__StreamEncoderWriteStatus result = FLAC__STREAM_ENCODER_WRITE_STATUS_OK;
  UnifexEnv *env = unifex_alloc_env();
  State *state = (State *)client_data;
  UnifexPayload *payload =
      unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, bytes);
  memcpy(payload->data, buffer, bytes);
  if (!send_encoded(env, state->pid, UNIFEX_SEND_THREADED, payload)) {
    MEMBRANE_THREADED_WARN(env, "Failed to send encoded data");
    result = FLAC__STREAM_ENCODER_WRITE_STATUS_FATAL_ERROR;
    goto handle_encoded_exit;
  }
handle_encoded_exit:
  unifex_payload_release(payload);
  unifex_free_env(env);

  return result;
}
