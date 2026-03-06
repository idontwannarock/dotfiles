## ADDED Requirements

### Requirement: Calculate output token speed from JSONL
The statusline SHALL calculate output tokens per second by parsing the current session's JSONL file, extracting timestamps and output_tokens from recent assistant responses.

#### Scenario: JSONL with recent assistant responses
- **WHEN** the session JSONL contains assistant responses with timestamps and usage data
- **THEN** the statusline calculates output tokens / duration in seconds from the most recent responses

#### Scenario: JSONL not found or empty
- **WHEN** the session JSONL cannot be found or contains no assistant responses
- **THEN** the token speed section is omitted from output

#### Scenario: Display format
- **WHEN** token speed is calculated successfully
- **THEN** it is displayed as `⚡ XX.X t/s` on line 1
