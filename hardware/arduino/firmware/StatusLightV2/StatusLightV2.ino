#include <FastLED.h>
#include <ctype.h>
#include <string.h>

#define NUM_LEDS 24
#define DATA_PIN 10
#define BRIGHTNESS 128
#define SERIAL_BAUD 115200
#define LED_TYPE WS2812B
#define COLOR_ORDER GRB
#define INPUT_MAX 48
#define FRAME_MS 25

enum AgentState : uint8_t {
  STATE_IDLE,
  STATE_THINKING,
  STATE_WORKING,
  STATE_WAITING,
  STATE_SUCCESS,
  STATE_ERROR,
  STATE_UNKNOWN
};

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
void renderIdle();
void renderThinking(uint32_t now);
void renderWorking(uint32_t now);
void renderWaiting();
void renderSuccess(uint32_t now);
void renderError(uint32_t now);
void renderUnknown();
void setPixelWrapped(int index, const CRGB &color);

void setup() {
  Serial.begin(SERIAL_BAUD);

  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  FastLED.setCorrection(TypicalLEDStrip);
  FastLED.setMaxPowerInVoltsAndMilliamps(5, 1500);

  stateStartedAt = millis();
  renderUnknown();
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
      renderIdle();
      break;
    case STATE_THINKING:
      renderThinking(now);
      break;
    case STATE_WORKING:
      renderWorking(now);
      break;
    case STATE_WAITING:
      renderWaiting();
      break;
    case STATE_SUCCESS:
      renderSuccess(now);
      break;
    case STATE_ERROR:
      renderError(now);
      break;
    default:
      renderUnknown();
      break;
  }
}

void renderIdle() {
  uint8_t level = beatsin8(10, 35, 110);
  fill_solid(leds, NUM_LEDS, CRGB(0, level, 0));
}

void renderThinking(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB(0, 0, 18));

  int head = (now / 90) % NUM_LEDS;
  setPixelWrapped(head, CRGB(30, 120, 255));
  setPixelWrapped(head - 1, CRGB(0, 55, 170));
  setPixelWrapped(head - 2, CRGB(0, 20, 90));
}

void renderWorking(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB(32, 20, 0));

  int head = (now / 55) % NUM_LEDS;
  for (uint8_t i = 0; i < 5; i++) {
    uint8_t fade = 255 - (i * 45);
    CRGB color = CRGB(255, 170, 0);
    color.nscale8_video(fade);
    setPixelWrapped(head - i, color);
  }
}

void renderWaiting() {
  uint8_t level = beatsin8(18, 20, 150);
  fill_solid(leds, NUM_LEDS, CRGB(level, 0, level));
}

void renderSuccess(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB(0, 120, 20));

  int offset = (now / 70) % NUM_LEDS;
  setPixelWrapped(offset, CRGB::White);
  setPixelWrapped(offset + 8, CRGB(120, 255, 120));
  setPixelWrapped(offset + 16, CRGB(120, 255, 120));
}

void renderError(uint32_t now) {
  bool on = ((now - stateStartedAt) / 180) % 2 == 0;
  fill_solid(leds, NUM_LEDS, on ? CRGB(255, 0, 0) : CRGB(20, 0, 0));
}

void renderUnknown() {
  fill_solid(leds, NUM_LEDS, CRGB(0, 0, 70));
}

void setPixelWrapped(int index, const CRGB &color) {
  while (index < 0) {
    index += NUM_LEDS;
  }

  leds[index % NUM_LEDS] = color;
}
