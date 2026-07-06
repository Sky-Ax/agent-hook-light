#include <FastLED.h>
#include <ctype.h>
#include <string.h>

#define NUM_LEDS 24
#define DATA_PIN 10
#define BRIGHTNESS 72
#define SERIAL_BAUD 115200
#define LED_TYPE WS2812B
#define COLOR_ORDER GRB
#define INPUT_MAX 48
#define FRAME_MS 25
#define WAITING_FLASH_MS 800

enum AgentState : uint8_t {
  STATE_IDLE,
  STATE_THINKING,
  STATE_WORKING,
  STATE_WAITING,
  STATE_SUCCESS,
  STATE_ERROR,
  STATE_UNKNOWN
};

const CRGB IDLE_COLOR = CRGB(0, 220, 90);
const CRGB THINKING_COLOR = CRGB(30, 110, 255);
const CRGB WORKING_COLOR = CRGB(255, 140, 0);
const CRGB WAITING_COLOR = CRGB(150, 45, 255);
const CRGB SUCCESS_COLOR = CRGB(0, 255, 0);
const CRGB ERROR_COLOR = CRGB(255, 0, 0);
const CRGB UNKNOWN_COLOR = CRGB(0, 0, 160);

CRGB leds[NUM_LEDS];

AgentState currentState = STATE_UNKNOWN;
char inputLine[INPUT_MAX];
uint8_t inputLength = 0;
uint32_t stateStartedAt = 0;
uint32_t lastFrameAt = 0;

void handleSerial();
void processInputLine();
AgentState parseState(char *value);
void normalizeInput(char *value);
void setState(AgentState nextState);
void renderState(uint32_t now);
void renderIdle(uint32_t now);
void renderThinking(uint32_t now);
void renderWorking(uint32_t now);
void renderWaiting(uint32_t now);
void renderSuccess(uint32_t now);
void renderError(uint32_t now);
void renderUnknown(uint32_t now);
void fillRing(const CRGB &color, uint8_t scale);
void drawChase(uint32_t now, const CRGB &color, uint8_t count, uint16_t speedMs);
void drawOppositeDots(uint32_t now, const CRGB &color, uint16_t speedMs);
void drawSingleScan(uint32_t now, const CRGB &color, uint16_t speedMs);
void drawWaitingCue(bool active);
void drawUnknownCue(uint32_t now);
void setPixelWrapped(int index, const CRGB &color);
CRGB scaledColor(CRGB color, uint8_t scale);

void setup() {
  Serial.begin(SERIAL_BAUD);

  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  FastLED.setCorrection(TypicalLEDStrip);
  FastLED.setMaxPowerInVoltsAndMilliamps(5, 1500);

  stateStartedAt = millis();
  renderUnknown(stateStartedAt);
  FastLED.show();
}

void loop() {
  handleSerial();

  uint32_t now = millis();
  if (now - lastFrameAt >= FRAME_MS) {
    lastFrameAt = now;
    renderState(now);
    FastLED.show();
  }
}

void handleSerial() {
  while (Serial.available() > 0) {
    char ch = (char)Serial.read();

    if (ch == '\n') {
      processInputLine();
      continue;
    }

    if (ch == '\r') {
      continue;
    }

    if (inputLength < INPUT_MAX - 1) {
      inputLine[inputLength++] = ch;
    } else {
      inputLength = 0;
    }
  }
}

void processInputLine() {
  inputLine[inputLength] = '\0';
  inputLength = 0;

  setState(parseState(inputLine));
}

AgentState parseState(char *value) {
  normalizeInput(value);

  if (strcmp(value, "idle") == 0) {
    return STATE_IDLE;
  }

  if (strcmp(value, "thinking") == 0 || strcmp(value, "submitted") == 0) {
    return STATE_THINKING;
  }

  if (strcmp(value, "working") == 0 || strcmp(value, "tool_running") == 0) {
    return STATE_WORKING;
  }

  if (strcmp(value, "waiting") == 0 || strcmp(value, "waiting_user") == 0 || strcmp(value, "waiting_permission") == 0) {
    return STATE_WAITING;
  }

  if (strcmp(value, "success") == 0 || strcmp(value, "done") == 0 || strcmp(value, "complete") == 0) {
    return STATE_SUCCESS;
  }

  if (strcmp(value, "error") == 0 || strcmp(value, "failed") == 0 || strcmp(value, "failure") == 0 || strcmp(value, "attention") == 0) {
    return STATE_ERROR;
  }

  if (strcmp(value, "unknown") == 0) {
    return STATE_UNKNOWN;
  }

  return STATE_UNKNOWN;
}

void normalizeInput(char *value) {
  char *read = value;
  while (*read != '\0' && isspace(static_cast<unsigned char>(*read))) {
    read++;
  }

  char *write = value;
  while (*read != '\0') {
    *write = static_cast<char>(tolower(static_cast<unsigned char>(*read)));
    write++;
    read++;
  }
  *write = '\0';

  while (write > value) {
    char *previous = write - 1;
    if (!isspace(static_cast<unsigned char>(*previous))) {
      break;
    }
    *previous = '\0';
    write = previous;
  }
}

void setState(AgentState nextState) {
  if (nextState == currentState) {
    return;
  }

  currentState = nextState;
  stateStartedAt = millis();
}

void renderState(uint32_t now) {
  switch (currentState) {
    case STATE_IDLE:
      renderIdle(now);
      break;
    case STATE_THINKING:
      renderThinking(now);
      break;
    case STATE_WORKING:
      renderWorking(now);
      break;
    case STATE_WAITING:
      renderWaiting(now);
      break;
    case STATE_SUCCESS:
      renderSuccess(now);
      break;
    case STATE_ERROR:
      renderError(now);
      break;
    default:
      renderUnknown(now);
      break;
  }
}

void renderIdle(uint32_t now) {
  fillRing(IDLE_COLOR, 110);

  uint32_t age = now - stateStartedAt;
  if (age < 1400) {
    drawSingleScan(now, IDLE_COLOR, 55);
  }
}

void renderThinking(uint32_t now) {
  fillRing(THINKING_COLOR, 14);
  drawChase(now, THINKING_COLOR, 4, 58);
}

void renderWorking(uint32_t now) {
  fillRing(WORKING_COLOR, 22);
  drawOppositeDots(now, WORKING_COLOR, 120);
}

void renderWaiting(uint32_t now) {
  fillRing(WAITING_COLOR, 42);

  uint32_t age = now - stateStartedAt;
  bool active = (age % WAITING_FLASH_MS) < 280;
  drawWaitingCue(active);
}

void renderSuccess(uint32_t now) {
  fillRing(SUCCESS_COLOR, 36);
  drawSingleScan(now, SUCCESS_COLOR, 180);
}

void renderError(uint32_t now) {
  uint32_t age = now - stateStartedAt;
  uint16_t flashWindow = age % 900;
  bool flash = flashWindow < 120 || (flashWindow > 210 && flashWindow < 330) || (flashWindow > 420 && flashWindow < 540);

  fillRing(ERROR_COLOR, flash ? 185 : 25);
}

void renderUnknown(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  drawUnknownCue(now);
}

void fillRing(const CRGB &color, uint8_t scale) {
  fill_solid(leds, NUM_LEDS, scaledColor(color, scale));
}

void drawChase(uint32_t now, const CRGB &color, uint8_t count, uint16_t speedMs) {
  int head = (now / speedMs) % NUM_LEDS;
  for (uint8_t i = 0; i < count; i++) {
    int fade = 128 - (i * 26);
    if (fade < 36) {
      fade = 36;
    }
    setPixelWrapped(head - i, scaledColor(color, (uint8_t)fade));
  }
}

void drawOppositeDots(uint32_t now, const CRGB &color, uint16_t speedMs) {
  int head = (now / speedMs) % NUM_LEDS;
  setPixelWrapped(head, scaledColor(color, 210));
  setPixelWrapped(head + (NUM_LEDS / 2), scaledColor(color, 170));
}

void drawSingleScan(uint32_t now, const CRGB &color, uint16_t speedMs) {
  int head = (now / speedMs) % NUM_LEDS;
  setPixelWrapped(head, scaledColor(color, 190));
}

void drawWaitingCue(bool active) {
  CRGB center = active ? CRGB::White : scaledColor(WAITING_COLOR, 150);
  CRGB side = active ? scaledColor(WAITING_COLOR, 220) : scaledColor(WAITING_COLOR, 110);

  setPixelWrapped(0, center);
  setPixelWrapped(1, side);
  setPixelWrapped(23, side);
}

void drawUnknownCue(uint32_t now) {
  uint16_t phase = (now - stateStartedAt) % 2400;
  if (phase < 780) {
    CRGB cue = scaledColor(UNKNOWN_COLOR, 48);
    setPixelWrapped(23, cue);
    setPixelWrapped(0, cue);
    setPixelWrapped(1, cue);
  }
}

void setPixelWrapped(int index, const CRGB &color) {
  while (index < 0) {
    index += NUM_LEDS;
  }

  leds[index % NUM_LEDS] = color;
}

CRGB scaledColor(CRGB color, uint8_t scale) {
  color.nscale8_video(scale);
  return color;
}
