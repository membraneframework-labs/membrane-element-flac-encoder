#pragma once

#define MEMBRANE_LOG_TAG "Membrane.Element.FLAC.Encoder"

#include <FLAC/stream_encoder.h>
#include <membrane/log.h>
#include <membrane/membrane.h>
#include <stdint.h>

typedef struct _EncoderState {
  FLAC__StreamEncoder *encoder;
  UnifexPid pid;
  unsigned sample_size;
  unsigned channels;
} UnifexNifState;

typedef UnifexNifState State;

#include "_generated/encoder.h"
