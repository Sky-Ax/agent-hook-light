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
#define TRANSITION_MS 320

enum AgentState : uint8_t {
  STATE_IDLE,
  STATE_THINKING,
  STATE_WORKING,
  STATE_WAITING,
  STATE_SUCCESS,
  STATE_ERROR,
  STATE_UNKNOWN
};

const int LEFT_EYE = 21;
const int RIGHT_EYE = 3;
const int SMILE_START = 10;

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
void renderIdleBot(uint32_t now);
void renderThinkingBot(uint32_t now);
void renderWorkingBot(uint32_t now);
void renderWaitingBot(uint32_t now);
void renderSuccessBot(uint32_t now);
void renderErrorBot(uint32_t now);
void renderUnknownBot(uint32_t now);
void drawBotEyes(int offset, uint8_t width, const CRGB &color, uint8_t intensity);
void drawEye(int center, uint8_t width, const CRGB &color, uint8_t intensity);
void drawSmile(const CRGB &color, uint8_t intensity);
void drawRingTrail(int head, const CRGB &color, uint8_t count, uint8_t fadeStep);
void drawTransitionSpark(uint32_t now);
void addPixelWrapped(int index, const CRGB &color);
void setPixelWrapped(int index, const CRGB &color);
CRGB scaledColor(CRGB color, uint8_t scale);

void setup() {
  Serial.begin(SERIAL_BAUD);

  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  FastLED.setCorrection(TypicalLEDStrip);
  FastLED.setMaxPowerInVoltsAndMilliamps(5, 1500);

  stateStartedAt = millis();
  renderUnknownBot(stateStartedAt);
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
      renderIdleBot(now);
      break;
    case STATE_THINKING:
      renderThinkingBot(now);
      break;
    case STATE_WORKING:
      renderWorkingBot(now);
      break;
    case STATE_WAITING:
      renderWaitingBot(now);
      break;
    case STATE_SUCCESS:
      renderSuccessBot(now);
      break;
    case STATE_ERROR:
      renderErrorBot(now);
      break;
    default:
      renderUnknownBot(now);
      break;
  }

  drawTransitionSpark(now);
}

void renderIdleBot(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB::Black);

  uint32_t age = now - stateStartedAt;
  uint16_t glancePhase = age % 5600;
  int glance = 0;
  if (glancePhase > 3300 && glancePhase < 4100) {
    glance = -1;
  } else if (glancePhase > 4450 && glancePhase < 5200) {
    glance = 1;
  }

  bool blink = (age % 3600) < 110 || (age % 8200) < 90;
  drawBotEyes(glance, blink ? 0 : 1, CRGB(0, 220, 170), blink ? 45 : 230);
  drawSmile(CRGB(0, 90, 65), 80);

  if (!blink && glancePhase > 4700 && glancePhase < 5000) {
    addPixelWrapped(RIGHT_EYE + glance - 1, scaledColor(CRGB::White, 120));
  }
}

void renderThinkingBot(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB(0, 0, 10));

  int orbit = (now / 80) % NUM_LEDS;
  drawRingTrail(orbit, CRGB(35, 115, 255), 5, 42);
  drawRingTrail(orbit + 12, CRGB(0, 45, 140), 3, 48);

  int gaze = ((now - stateStartedAt) / 700) % 2 == 0 ? -1 : 0;
  drawBotEyes(gaze, 1, CRGB(35, 150, 255), 245);
  addPixelWrapped(0, scaledColor(CRGB(120, 210, 255), 120));
  addPixelWrapped(1, scaledColor(CRGB(120, 210, 255), 70));
  addPixelWrapped(23, scaledColor(CRGB(120, 210, 255), 70));
}

void renderWorkingBot(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB(18, 9, 0));

  int head = (now / 45) % NUM_LEDS;
  drawRingTrail(head, CRGB(255, 150, 0), 7, 34);

  bool squint = ((now - stateStartedAt) / 180) % 2 == 0;
  drawBotEyes(0, squint ? 0 : 1, CRGB(255, 170, 30), 245);

  for (uint8_t i = 0; i < 7; i++) {
    uint8_t scale = 35 + (((now / 70) + i * 25) % 90);
    addPixelWrapped(SMILE_START + i, scaledColor(CRGB(255, 95, 0), scale));
  }
}

void renderWaitingBot(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB::Black);

  uint32_t age = now - stateStartedAt;
  int focus = (age / 1200) % 2 == 0 ? 0 : 1;
  drawBotEyes(focus, 2, CRGB(190, 50, 255), 240);
  drawSmile(CRGB(90, 0, 130), 80);

  uint16_t ping = age % 1150;
  if (ping < 260) {
    uint8_t level = 255 - ping;
    addPixelWrapped(0, scaledColor(CRGB::White, level));
    addPixelWrapped(1, scaledColor(CRGB(190, 50, 255), level / 2));
    addPixelWrapped(23, scaledColor(CRGB(190, 50, 255), level / 2));
  }
}

void renderSuccessBot(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB(0, 20, 4));

  drawBotEyes(0, 2, CRGB(0, 255, 115), 255);
  drawSmile(CRGB(0, 220, 95), 185);

  int sweep = (now / 55) % NUM_LEDS;
  drawRingTrail(sweep, CRGB::White, 4, 45);
  drawRingTrail(sweep + 8, CRGB(50, 255, 90), 3, 42);
  drawRingTrail(sweep + 16, CRGB(0, 160, 70), 3, 48);
}

void renderErrorBot(uint32_t now) {
  uint32_t age = now - stateStartedAt;
  bool flash = (age / 165) % 2 == 0;
  fill_solid(leds, NUM_LEDS, flash ? CRGB(34, 0, 0) : CRGB::Black);

  int jitter = (age / 85) % 2 == 0 ? -1 : 1;
  drawBotEyes(jitter, 0, flash ? CRGB(255, 0, 0) : CRGB(120, 0, 0), 255);

  if (flash) {
    addPixelWrapped(0, CRGB(255, 0, 0));
    addPixelWrapped(8, CRGB(170, 0, 0));
    addPixelWrapped(16, CRGB(170, 0, 0));
  }
}

void renderUnknownBot(uint32_t now) {
  fill_solid(leds, NUM_LEDS, CRGB(0, 0, 12));

  int wobble = (int)((now / 520) % 3) - 1;
  drawEye(LEFT_EYE + wobble, 1, CRGB(0, 160, 220), 180);
  drawEye(RIGHT_EYE - wobble, 0, CRGB(150, 60, 255), 220);

  int dot = (now / 180) % NUM_LEDS;
  addPixelWrapped(dot, scaledColor(CRGB(80, 80, 255), 80));
}

void drawBotEyes(int offset, uint8_t width, const CRGB &color, uint8_t intensity) {
  drawEye(LEFT_EYE + offset, width, color, intensity);
  drawEye(RIGHT_EYE + offset, width, color, intensity);
}

void drawEye(int center, uint8_t width, const CRGB &color, uint8_t intensity) {
  addPixelWrapped(center, scaledColor(color, intensity));

  if (width >= 1) {
    addPixelWrapped(center - 1, scaledColor(color, intensity / 2));
    addPixelWrapped(center + 1, scaledColor(color, intensity / 2));
  }

  if (width >= 2) {
    addPixelWrapped(center - 2, scaledColor(color, intensity / 4));
    addPixelWrapped(center + 2, scaledColor(color, intensity / 4));
  }
}

void drawSmile(const CRGB &color, uint8_t intensity) {
  for (uint8_t i = 0; i < 5; i++) {
    uint8_t distanceFromCenter = abs((int)i - 2);
    uint8_t scale = intensity - (distanceFromCenter * 28);
    addPixelWrapped(SMILE_START + i, scaledColor(color, scale));
  }
}

void drawRingTrail(int head, const CRGB &color, uint8_t count, uint8_t fadeStep) {
  for (uint8_t i = 0; i < count; i++) {
    uint8_t scale = 255 - min((int)i * fadeStep, 230);
    addPixelWrapped(head - i, scaledColor(color, scale));
  }
}

void drawTransitionSpark(uint32_t now) {
  uint32_t age = now - stateStartedAt;
  if (age > TRANSITION_MS) {
    return;
  }

  int head = (now / 28) % NUM_LEDS;
  drawRingTrail(head, CRGB::White, 4, 58);
}

void addPixelWrapped(int index, const CRGB &color) {
  while (index < 0) {
    index += NUM_LEDS;
  }

  uint8_t pixel = index % NUM_LEDS;
  leds[pixel].r = qadd8(leds[pixel].r, color.r);
  leds[pixel].g = qadd8(leds[pixel].g, color.g);
  leds[pixel].b = qadd8(leds[pixel].b, color.b);
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
