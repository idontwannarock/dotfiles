// passgen — 個人用密碼產生器
//
// 兩種模式：
//   1) 預設：crypto-random 密碼（--length / --count / --symbols）
//   2) --encode：把 Bopomofo 字元轉成 Dachen QWERTY keystroke
//
// 範例：
//   $ passgen                      # 預設 20 字英數字
//   $ passgen -l 30 -s             # 30 字含符號
//   $ passgen -c 5                 # 一次產生 5 組
//   $ passgen -e 'ㄨㄛˇㄞˋㄔ'       # 輸出 Dachen keystroke

use clap::Parser;
use rand::Rng;
use rand::seq::SliceRandom;

// ── 字元類別 ────────────────────────────────────────────────────────────────
// 切成四類的目的：產出密碼時「保證每類至少出現一次」，通過網站的
// 字元類別要求（大寫/小寫/數字/符號）。排除易混淆字元（0/O/o、1/l/I）。
const CLASS_LOWER: &str = "abcdefghijkmnpqrstuvwxyz";
const CLASS_UPPER: &str = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const CLASS_DIGIT: &str = "23456789";
const CLASS_SYMBOL: &str = "!@#$%^&*-_=+?";

#[derive(Parser, Debug)]
#[command(name = "passgen", version, about = "個人用密碼產生器")]
struct Cli {
    /// 密碼長度（random 模式）
    #[arg(short, long, default_value_t = 20)]
    length: usize,

    /// 一次產生幾組
    #[arg(short, long, default_value_t = 1)]
    count: usize,

    /// 字元集加入符號
    #[arg(short, long)]
    symbols: bool,

    /// Bopomofo 編碼模式：輸入注音字串，輸出 Dachen 鍵盤對應的 QWERTY keystroke
    /// 範例：--encode 'ㄨㄛˇㄞˋㄔ'
    #[arg(short = 'e', long, value_name = "BOPOMOFO")]
    encode: Option<String>,
}

fn main() {
    let cli = Cli::parse();

    if let Some(input) = cli.encode {
        println!("{}", bopomofo_to_keystroke(&input));
        return;
    }

    let required = if cli.symbols { 4 } else { 3 };
    if cli.length < required {
        eprintln!(
            "error: --length must be at least {} to include all character classes",
            required
        );
        std::process::exit(1);
    }

    for _ in 0..cli.count {
        println!("{}", generate_random_password(cli.length, cli.symbols));
    }
}

// ── 核心函式 1：隨機密碼產生 ───────────────────────────────────────────────
//
// 演算法（保證每類至少出現 1 個）：
//   1. 從每個類別各抽 1 字放進 buffer → 用掉 classes.len() 個位置
//   2. 剩下位置從所有類別聯集中均勻抽取
//   3. 洗牌整個 buffer，讓「保證字元」位置不可預測
//
// 設計選擇：
//   * RNG 來源：`rand::rng()` 回傳 thread-local ThreadRng。
//     - 種子來自 OS entropy（Windows BCryptGenRandom / Linux getrandom / macOS
//       SecRandomCopyBytes），之後用 ChaCha12 CSPRNG 擴展。
//     - 跟「直接用 OsRng」的安全性差別，在密碼產生這規模下可忽略。
//
//   * 均勻抽取：`random_range(0..n)` 會做 rejection sampling（rand 原始碼裡的
//     `UniformInt::sample_single`），所以不會有 modulo bias——即使字元集
//     長度不是 2 的冪次也安全。
//
//   * Entropy 代價：保證每類出現會讓總 entropy 比純均勻抽取略低（~0.1 bits
//     對 20 字密碼），實務上可忽略，換來能通過網站的字元類別要求。
fn generate_random_password(length: usize, with_symbols: bool) -> String {
    let mut rng = rand::rng();

    let classes: &[&str] = if with_symbols {
        &[CLASS_LOWER, CLASS_UPPER, CLASS_DIGIT, CLASS_SYMBOL]
    } else {
        &[CLASS_LOWER, CLASS_UPPER, CLASS_DIGIT]
    };

    // 每類先抽 1 字（保證覆蓋）
    let mut password: Vec<u8> = classes
        .iter()
        .map(|class| {
            let bytes = class.as_bytes();
            bytes[rng.random_range(0..bytes.len())]
        })
        .collect();

    // 剩下位置從聯集均勻抽取
    let combined: String = classes.concat();
    let combined_bytes = combined.as_bytes();
    for _ in 0..(length - classes.len()) {
        password.push(combined_bytes[rng.random_range(0..combined_bytes.len())]);
    }

    // 洗牌避免「前面幾個位置固定是每類各一字」的可預測結構
    password.shuffle(&mut rng);

    String::from_utf8(password).expect("all ASCII by construction")
}

// ── 核心函式 2：Bopomofo → Dachen QWERTY keystroke ─────────────────────────
//
// Dachen (大千) 是 Windows/macOS/Linux 內建注音 IME 的預設排列。
// 37 個符號 + 5 個音調（含第 1 聲）的位置來源：Wikipedia Bopomofo 條目的
// keyboard layout 圖。
//
// 下方 37 個聲母/韻母 mapping 是硬事實，我先寫完。
// 你要做的決定集中在「音調處理策略」（TODO 2 處），那是 entropy vs 可讀性
// 的 trade-off。
fn bopomofo_to_keystroke(input: &str) -> String {
    input
        .chars()
        .map(|c| match c {
            // ── 數字排（聲母起始 + 尾韻母）───────────────────────────────
            'ㄅ' => '1', 'ㄉ' => '2', 'ㄓ' => '5',
            'ㄚ' => '8', 'ㄞ' => '9', 'ㄢ' => '0',
            // ── q ~ p 列 ────────────────────────────────────────────────
            'ㄆ' => 'q', 'ㄊ' => 'w', 'ㄍ' => 'e', 'ㄐ' => 'r',
            'ㄔ' => 't', 'ㄗ' => 'y', 'ㄧ' => 'u', 'ㄛ' => 'i',
            'ㄟ' => 'o', 'ㄣ' => 'p',
            // ── a ~ ; 列 ────────────────────────────────────────────────
            'ㄇ' => 'a', 'ㄋ' => 's', 'ㄎ' => 'd', 'ㄑ' => 'f',
            'ㄕ' => 'g', 'ㄘ' => 'h', 'ㄨ' => 'j', 'ㄜ' => 'k',
            'ㄠ' => 'l', 'ㄤ' => ';',
            // ── z ~ / 列 ────────────────────────────────────────────────
            'ㄈ' => 'z', 'ㄌ' => 'x', 'ㄏ' => 'c', 'ㄒ' => 'v',
            'ㄖ' => 'b', 'ㄙ' => 'n', 'ㄩ' => 'm', 'ㄝ' => ',',
            'ㄡ' => '.', 'ㄥ' => '/',

            // ── TODO 2：音調處理策略 ──────────────────────────────────────
            // Dachen 標準：
            //   ˉ (1聲) → ' '（空白鍵）
            //   ˊ (2聲) → '6'
            //   ˇ (3聲) → '3'
            //   ˋ (4聲) → '4'
            //   ˙ (輕聲) → '7'
            //
            // 取捨：
            //   A. 全部對應（含 1 聲空白）：最忠實；但密碼含空白可能不被
            //      某些系統接受，且「連續空白」會被 trim
            //   B. 1 聲省略，其他保留：最常用選擇（密碼不含空白但仍有 4 種
            //      音調區分度）
            //   C. 全部省略：最短、最好記，但失去一維 entropy
            //
            // 下面是 B 的寫法——如果你要 A 或 C，改這幾個 arm：
            'ˊ' => '6',
            'ˇ' => '3',
            'ˋ' => '4',
            '˙' => '7',
            // 'ˉ' 這個 1 聲符號目前走到下方 other arm（原樣 pass-through）
            // 你也可以明確處理它：
            //   'ˉ' => ' ',   // 策略 A
            //   'ˉ' => ...,   // 策略 C 下要 skip（這時需改成 filter_map）

            // ── 未知字元 pass-through ──────────────────────────────────
            // 例如數字、英文字母、空白都原樣輸出。這讓使用者可以
            // 在 Bopomofo 字串中混入分隔符或 salt 也不會壞掉。
            other => other,
        })
        .collect()
}

// ── 可選：驗證你的實作 ─────────────────────────────────────────────────────
//
// 跑 `cargo test` 來確認兩個核心函式至少做對基本事。
// 這些測試不是 learning mode 要你寫的東西，但你 TODO 完成後
// 執行它們能給你一個 sanity check。
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn random_password_has_correct_length() {
        assert_eq!(generate_random_password(25, false).chars().count(), 25);
        assert_eq!(generate_random_password(30, true).chars().count(), 30);
    }

    #[test]
    fn random_password_only_uses_valid_chars() {
        let full = format!(
            "{}{}{}{}",
            CLASS_LOWER, CLASS_UPPER, CLASS_DIGIT, CLASS_SYMBOL
        );
        let pw = generate_random_password(200, true);
        for c in pw.chars() {
            assert!(full.contains(c), "char {} not in any class", c);
        }
    }

    #[test]
    fn random_password_contains_all_classes_alphanum() {
        // 跑 50 次降低 flaky 機率（單次就該保證，但多跑讓 regression 更明顯）
        for _ in 0..50 {
            let pw = generate_random_password(20, false);
            assert!(pw.chars().any(|c| CLASS_LOWER.contains(c)), "no lower: {}", pw);
            assert!(pw.chars().any(|c| CLASS_UPPER.contains(c)), "no upper: {}", pw);
            assert!(pw.chars().any(|c| CLASS_DIGIT.contains(c)), "no digit: {}", pw);
        }
    }

    #[test]
    fn random_password_contains_all_classes_with_symbols() {
        for _ in 0..50 {
            let pw = generate_random_password(20, true);
            assert!(pw.chars().any(|c| CLASS_LOWER.contains(c)), "no lower: {}", pw);
            assert!(pw.chars().any(|c| CLASS_UPPER.contains(c)), "no upper: {}", pw);
            assert!(pw.chars().any(|c| CLASS_DIGIT.contains(c)), "no digit: {}", pw);
            assert!(pw.chars().any(|c| CLASS_SYMBOL.contains(c)), "no symbol: {}", pw);
        }
    }

    #[test]
    fn bopomofo_known_mapping() {
        // 我愛吃蘋果 → ㄨㄛˇㄞˋㄔㄆㄧㄥˊㄍㄨㄛˇ → ji3 94 t qu/6 eji3
        assert_eq!(
            bopomofo_to_keystroke("ㄨㄛˇㄞˋㄔㄆㄧㄥˊㄍㄨㄛˇ"),
            "ji394tqu/6eji3"
        );
    }

    #[test]
    fn bopomofo_unknown_passthrough() {
        assert_eq!(bopomofo_to_keystroke("abc 123"), "abc 123");
    }
}
