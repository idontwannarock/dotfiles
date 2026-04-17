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

// ── 字元集 ─────────────────────────────────────────────────────────────────
// 這兩個字串是「你這把工具的個性」。常見的權衡：
//   * 是否排除易混淆字元（0/O/o、1/l/I）→ 下面已排除，你若不介意可加回來
//   * 符號選哪些 → 過於極端的符號（空白、反斜線、引號）在某些登入框會壞事
//
// TODO（低優先）：如果你想改口味，動這兩個常數即可。
const CHARSET_ALPHANUM: &str =
    "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CHARSET_WITH_SYMBOLS: &str =
    "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*-_=+?";

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

    let charset = if cli.symbols {
        CHARSET_WITH_SYMBOLS
    } else {
        CHARSET_ALPHANUM
    };
    let charset_bytes = charset.as_bytes();

    for _ in 0..cli.count {
        println!("{}", generate_random_password(charset_bytes, cli.length));
    }
}

// ── 核心函式 1：隨機密碼產生 ───────────────────────────────────────────────
//
// 這幾行是工具的安全核心。設計選擇：
//
//   * RNG 來源：`rand::rng()` 回傳 thread-local ThreadRng。
//     - 種子來自 OS entropy（Windows BCryptGenRandom / Linux getrandom / macOS
//       SecRandomCopyBytes），之後用 ChaCha12 CSPRNG 擴展。
//     - 週期性 reseed，不會被同一進程長期使用耗盡。
//     - 跟「直接用 OsRng」的安全性差別，在密碼產生這規模下可忽略。
//
//   * 均勻抽取：`random_range(0..n)` 會做 rejection sampling（rand 原始碼裡的
//     `UniformInt::sample_single`），所以不會有 modulo bias——即使 charset
//     長度不是 2 的冪次也安全。
//
//   * 為何不自己拿 bytes 做 rejection：可以，但只會增加 code 量跟 bug 表面；
//     除非不信任 rand crate 本身，不然沒有實質安全增益。
fn generate_random_password(charset: &[u8], length: usize) -> String {
    let mut rng = rand::rng();
    (0..length)
        .map(|_| charset[rng.random_range(0..charset.len())] as char)
        .collect()
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
        let pw = generate_random_password(CHARSET_ALPHANUM.as_bytes(), 25);
        assert_eq!(pw.chars().count(), 25);
    }

    #[test]
    fn random_password_only_uses_charset() {
        let charset = CHARSET_ALPHANUM;
        let pw = generate_random_password(charset.as_bytes(), 100);
        for c in pw.chars() {
            assert!(charset.contains(c), "char {} not in charset", c);
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
