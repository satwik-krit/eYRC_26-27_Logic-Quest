/*
* Logic Quest (LQ): Task 3A Path Planner with Decryption
*
* Computes the shortest path on the Logic Quest arena (nodes N1..N36), with the
* line weights of Figure 1 on the Task 3A page: straight line 5, ring arcs
* 7 / 11 / 15 / 19 (inner ring to outermost ring), wavy line N1-N36 100.
*
* Inputs : current_node, next_node, is_encrypted
*   current_node     : where the bot is, 1..36. The path starts here.
*                      At the first location the bot is in the start box, N35.
*   is_encrypted = 0 : next_node is a node number.
*                      Path: current_node -> next_node.
*   is_encrypted = 1 : next_node is the 8-byte encrypted code, encrypted with
*                      PRESENT-80.
*                      Path: current_node -> the drop node in the block.
*
* Decrypted code (8 bytes, byte 0 first):
*   byte 0     : done flag (1 = last block: no pick-up after this drop)
*   byte 1..5  : message, 5 ASCII characters (0x00 = no character)
*   byte 6     : next pick-up node 1..36 (not used when the done flag is 1)
*   byte 7     : drop node 1..36 for this block
*   e.g. message "HELLO", drop at N26, then pick up at N12
*        -> 00 48 45 4C 4C 4F 0C 1A = 0048454C4C4F0C1A
*
* Outputs:
*   is_encrypted = 0 : the path from current_node to next_node.
*   is_encrypted = 1 : the message (message[]) and the path from current_node
*                      to the drop node. When the done flag is 0, the inputs
*                      for the next run are written too:
*                          IS_ENCRYPTED = 0
*                          CURRENT_NODE = the drop node
*                          NEXT_NODE    = the next pick-up node
*                      When the done flag is 1, the inputs are left as they are.
*
* Output (PC), read by test.sh line by line:
*   is_encrypted = 0     is_encrypted = 1, done = 0     is_encrypted = 1, done = 1
*   35                   Message : HELLO                Message : BYE
*   ...                  7                              7
*   7                    ...                            ...
*                        26                             26
*                        Next current_node : 26         Done
*                        Next next_node : 12
*   The path is one node per line, first node first. The message line shows
*   the non-zero message bytes as characters. The code at the end of main
*   prints all of this from message[], path_planned[], idx and the inputs
*   written for the next run.
*
* Debug prints: start every debug line with "dbg:" (see Functions Usage
*   below). test.sh and the evaluator skip the lines that start with "dbg:".
*   Any other extra line counts as part of your output and makes it wrong.
*
* PRESENT-80 (the cipher used for the encrypted codes):
*   block 64 bits, key 80 bits = A1 B2 C3 D4 E5 F6 07 18 29 3A (PRESENT_KEY_* below),
*   31 rounds. See the Task 3A page for the full description of the encryption;
*   your program has to do the reverse.
*
* Data memory ranges (used on the RISC-V CPU, Task 3B):
*   0x02000000 .. 0x0200000F : inputs
*   0x02000010 .. 0x0200001F : outputs (0x0200001C = CPU_DONE)
*   0x02000020 and up        : working memory, stack at the top
*
* Inputs  : ENCRYPTED_HI (0x02000000)  encrypted block, bytes 0..3 (first 8 hex digits)
*           ENCRYPTED_LO (0x02000004)  encrypted block, bytes 4..7 (last 8 hex digits)
*           IS_ENCRYPTED (0x02000008)  0 or 1                            } written for
*           NEXT_NODE    (0x0200000C)  next node, when IS_ENCRYPTED = 0   } the next run
*           CURRENT_NODE (0x0200000D)  current node (where the bot is)    } when done = 0
* Outputs : MESSAGE_0..4 (0x02000010 .. 0x02000014)  message, block bytes 1..5
*           NODE_POINT   (0x02000018)  every node of the path, written in order
*           CPU_DONE     (0x0200001C)  = 1 when finished
*
* Make sure you don't change anything outside the "Add your code here" sections.
*/

#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>

// PRESENT-80 key: A1 B2 C3 D4 E5 F6 07 18 29 3A
#define PRESENT_KEY_HI  0xA1B2C3D4   // key bits 79..48
#define PRESENT_KEY_MID 0xE5F60718   // key bits 47..16
#define PRESENT_KEY_LO  0x293A       // key bits 15..0

#ifdef __linux__ // for host pc

    #include <stdio.h>

    void _put_byte(char c) { putchar(c); }

    void _put_str(char *str) {
        while (*str) {
            _put_byte(*str++);
        }
    }

    void print_output(uint8_t num) {
        if (num == 0) {
            putchar('0'); // if the number is 0, directly print '0'
            _put_byte('\n');
            return;
        }

        // convert the integer to a string
        char buffer[20];
        uint8_t index = 0;

        while (num > 0) {
            buffer[index++] = '0' + num % 10; // convert the last digit to its character representation
            num /= 10;                        // move to the next digit
        }
        // print the characters in reverse order (from right to left)
        while (index > 0) { putchar(buffer[--index]); }
        _put_byte('\n');
    }

    void _put_value(uint8_t val) { print_output(val); }

    // print a 32-bit value as 8 hex digits and a newline (e.g. the decrypted block)
    void _put_hex(uint32_t val) { printf("%08X\n", (unsigned int)val); }

    // read 16 hex digits into two 32-bit words, returns 0 if the text is not 16 hex digits
    int read_block(const char *hex, uint32_t *hi, uint32_t *lo) {
        uint32_t word[2] = { 0, 0 };
        if (hex[0] == '0' && (hex[1] == 'x' || hex[1] == 'X')) hex += 2;
        for (int n = 0; n < 16; n++) {
            char c = hex[n];
            uint32_t d;
            if      (c >= '0' && c <= '9') d = c - '0';
            else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
            else return 0;
            word[n >> 3] = (word[n >> 3] << 4) | d;
        }
        if (hex[16] != '\0') return 0;
        *hi = word[0];
        *lo = word[1];
        return 1;
    }

    /*
     * On the PC there is no data memory at 0x02000000, so MEM32(address) is a
     * normal array (one entry per 32-bit word). On the CPU it is the real
     * data memory. Either way, MEM32(0x02000020) reads the same place.
     */
    static uint32_t pc_data_mem[128];
    #define MEM32(addr)  (pc_data_mem[((addr) - 0x02000000u) >> 2])

#else  // for the test device

    void _put_byte(char c) { }
    void _put_value(uint8_t val) { }
    void _put_hex(uint32_t val) { }
    void _put_str(char *str) { }

    #define MEM32(addr)  (*(volatile uint32_t *)(addr))

#endif

/*
Functions Usage

To print while debugging, use the functions below, not printf().
On the PC they print. On the CPU they are empty, so they cost nothing there
and the same file still builds with generatehex.sh.

for a character: _put_byte('A');                        (putchar() on the PC)
for newline:     _put_byte('\n');
for string:      _put_str("your string here");
for number:      _put_value(your_number_here);           0 to 255, then a newline
for 32 bits:     _put_hex(your_32_bit_value_here);       8 hex digits, then a newline

Start every debug line with "dbg:" and end it with a newline (_put_value
and _put_hex end the line for you). test.sh and the evaluator skip the
lines that start with "dbg:", so these prints can stay in the file you
submit. Any other line you print counts as part of your output (see
"Output (PC)" at the top) and makes it wrong.

Examples:
        _put_str("dbg: start_point = ");     _put_value(start_point);
        _put_str("dbg: end_point = ");       _put_value(end_point);
        _put_str("dbg: ENCRYPTED_HI = ");    _put_hex(ENCRYPTED_HI);    // encrypted block, bytes 0..3
        _put_str("dbg: ENCRYPTED_LO = ");    _put_hex(ENCRYPTED_LO);    // encrypted block, bytes 4..7
        _put_str("dbg: first character = "); _put_byte(message[0]); _put_byte('\n');
        _put_str("dbg: Hello World!\n");

*/

// Custom Functions

// ############# Add your code here #############

#define PIS(x) ((uint8_t)(((((x) & 8u) ? 0xA970364Bu : 0xD21C8FE5u) >> (((x) & 7u) << 2)) & 15u))
#define RD32(p) ((uint32_t)(p)[0] | ((uint32_t)(p)[1] << 8) | ((uint32_t)(p)[2] << 16) | ((uint32_t)(p)[3] << 24))
#define WR32(p,x) do { (p)[0] = (uint8_t)(x); (p)[1] = (uint8_t)((x) >> 8); (p)[2] = (uint8_t)((x) >> 16); (p)[3] = (uint8_t)((x) >> 24); } while (0)
#define RD16(p) ((uint16_t)((uint16_t)(p)[0] | ((uint16_t)(p)[1] << 8)))
#define WR16(p,x) do { (p)[0] = (uint8_t)(x); (p)[1] = (uint8_t)((x) >> 8); } while (0)
static void wr32(uint8_t *p, uint32_t x) {
    p[0] = (uint8_t)x;
    p[1] = (uint8_t)(x >> 8);
    p[2] = (uint8_t)(x >> 16);
    p[3] = (uint8_t)(x >> 24);
}
static void wr16(uint8_t *p, uint16_t x) {
    p[0] = (uint8_t)x;
    p[1] = (uint8_t)(x >> 8);
}
void key_prev_ws(uint8_t *w, uint8_t r) {
    uint8_t *k = w + 8;
    uint32_t h = RD32(k);
    uint32_t v = RD32(k + 4);
    uint16_t l = RD16(k + 8);
    uint32_t nh, nm;
    v ^= (uint32_t)(r >> 1);
    l ^= (uint16_t)((r & 1u) << 15);
    h = (h & 0x0FFFFFFFu) | ((uint32_t)PIS(h >> 28) << 28);
    nh = (h << 19) | (v >> 13);
    nm = (v << 19) | ((uint32_t)l << 3) | (h >> 29);
    WR32(k, nh);
    WR32(k + 4, nm);
    WR16(k + 8, (uint16_t)((h >> 13) | ((h >> 21) << 8)));
}
void inv_perm_ws(uint8_t *w) {
    uint32_t a = RD32(w), b = RD32(w + 4), oh = 0, ol = 0;
    uint8_t c;
    for (c = 0; c < 16u; ++c) {
        uint32_t nib = ((b >> c) & 1u)
                     | (((b >> (c + 16u)) & 1u) << 1)
                     | (((a >> c) & 1u) << 2)
                     | (((a >> (c + 16u)) & 1u) << 3);
        if (c < 8u) ol |= nib << (c << 2);
        else oh |= nib << ((c - 8u) << 2);
    }
    WR32(w, oh);
    WR32(w + 4, ol);
}
void inv_sbox_ws(uint8_t *w) {
    uint32_t h = RD32(w), l = RD32(w + 4), nh = 0, nl = 0;
    uint8_t i;
    for (i = 0; i < 8u; ++i) {
        uint32_t sh = (uint32_t)i << 2;
        nh |= (uint32_t)PIS((h >> sh) & 15u) << sh;
        nl |= (uint32_t)PIS((l >> sh) & 15u) << sh;
    }
    WR32(w, nh);
    WR32(w + 4, nl);
}
static void decrypt_ws(uint8_t *w) {
    volatile uint8_t *round = &w[18];
    for (uint8_t i = 0; i < 8u; ++i) w[i] ^= w[i + 8u];
    *round = 31u;
    while (*round) {
        key_prev_ws(w, *round);
        inv_perm_ws(w);
        inv_sbox_ws(w);
        for (uint8_t i = 0; i < 8u; ++i) w[i] ^= w[i + 8u];
        --*round;
    }
}

static uint16_t select_edge(uint8_t k, uint16_t a, uint16_t b, uint16_t c, uint16_t d) {
    uint16_t m0 = (uint16_t)(0u - (uint16_t)(k == 0u));
    uint16_t m1 = (uint16_t)(0u - (uint16_t)(k == 1u));
    uint16_t m2 = (uint16_t)(0u - (uint16_t)(k == 2u));
    uint16_t m3 = (uint16_t)(0u - (uint16_t)(k == 3u));
    return (uint16_t)((a & m0) | (b & m1) | (c & m2) | (d & m3));
}
uint16_t get_edge(uint8_t n, uint8_t k) {
    if (n == 0u || n > 36u) return 0;
    if (n == 20u) return select_edge(k, 0x0155u, 0x02C8u, 0x02DBu, 0x0000u);
    if (n <= 18u) {
        if (n <= 9u) {
            if (n <= 5u) {
                if (n <= 3u) {
                    if (n <= 2u) {
                        if (n <= 1u) {
                            return select_edge(k, 0x1924u, 0x0145u, 0x03C4u, 0x03C6u);
                        } else {
                            return select_edge(k, 0x0144u, 0x0000u, 0x0000u, 0x0000u);
                        }
                    } else {
                        return select_edge(k, 0x0146u, 0x0000u, 0x0000u, 0x0000u);
                    }
                } else {
                    if (n <= 4u) {
                        return select_edge(k, 0x0142u, 0x03C1u, 0x03CEu, 0x0000u);
                    } else {
                        return select_edge(k, 0x0141u, 0x02C7u, 0x02C8u, 0x0000u);
                    }
                }
            } else {
                if (n <= 7u) {
                    if (n <= 6u) {
                        return select_edge(k, 0x0143u, 0x03C1u, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x02C5u, 0x014Au, 0x02CFu, 0x0000u);
                    }
                } else {
                    if (n <= 8u) {
                        return select_edge(k, 0x02C5u, 0x014Bu, 0x02D4u, 0x0000u);
                    } else {
                        return select_edge(k, 0x01CBu, 0x014Cu, 0x0000u, 0x0000u);
                    }
                }
            }
        } else {
            if (n <= 14u) {
                if (n <= 12u) {
                    if (n <= 11u) {
                        if (n <= 10u) {
                            return select_edge(k, 0x0147u, 0x0000u, 0x0000u, 0x0000u);
                        } else {
                            return select_edge(k, 0x0148u, 0x01C9u, 0x01D3u, 0x0000u);
                        }
                    } else {
                        return select_edge(k, 0x0149u, 0x0000u, 0x0000u, 0x0000u);
                    }
                } else {
                    if (n <= 13u) {
                        return select_edge(k, 0x014Eu, 0x04DEu, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x014Du, 0x014Fu, 0x03C4u, 0x0000u);
                    }
                }
            } else {
                if (n <= 16u) {
                    if (n <= 15u) {
                        return select_edge(k, 0x014Eu, 0x02C7u, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x0151u, 0x01D7u, 0x0000u, 0x0000u);
                    }
                } else {
                    if (n <= 17u) {
                        return select_edge(k, 0x0150u, 0x0000u, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x0153u, 0x0000u, 0x0000u, 0x0000u);
                    }
                }
            }
        }
    } else {
        if (n <= 27u) {
            if (n <= 23u) {
                if (n <= 21u) {
                    if (n <= 20u) {
                        if (n <= 19u) {
                            return select_edge(k, 0x0152u, 0x01CBu, 0x0000u, 0x0000u);
                        } else {
                            return select_edge(k, 0x0155u, 0x0000u, 0x02C8u, 0x02DBu);
                        }
                    } else {
                        return select_edge(k, 0x0154u, 0x0000u, 0x0000u, 0x0000u);
                    }
                } else {
                    if (n <= 22u) {
                        return select_edge(k, 0x0159u, 0x0000u, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x01D0u, 0x01D9u, 0x015Au, 0x0000u);
                    }
                }
            } else {
                if (n <= 25u) {
                    if (n <= 24u) {
                        return select_edge(k, 0x015Bu, 0x0000u, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x0156u, 0x01D7u, 0x0000u, 0x0000u);
                    }
                } else {
                    if (n <= 26u) {
                        return select_edge(k, 0x0157u, 0x02DDu, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x0158u, 0x02D4u, 0x02DDu, 0x0000u);
                    }
                }
            }
        } else {
            if (n <= 32u) {
                if (n <= 30u) {
                    if (n <= 29u) {
                        if (n <= 28u) {
                            return select_edge(k, 0x015Fu, 0x03E0u, 0x0000u, 0x0000u);
                        } else {
                            return select_edge(k, 0x02DAu, 0x02DBu, 0x0160u, 0x0000u);
                        }
                    } else {
                        return select_edge(k, 0x0161u, 0x04CDu, 0x04E3u, 0x0000u);
                    }
                } else {
                    if (n <= 31u) {
                        return select_edge(k, 0x015Cu, 0x0162u, 0x04E3u, 0x0000u);
                    } else {
                        return select_edge(k, 0x015Du, 0x03DCu, 0x0000u, 0x0000u);
                    }
                }
            } else {
                if (n <= 34u) {
                    if (n <= 33u) {
                        return select_edge(k, 0x015Eu, 0x0000u, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x015Fu, 0x0000u, 0x0000u, 0x0000u);
                    }
                } else {
                    if (n <= 35u) {
                        return select_edge(k, 0x04DEu, 0x04DFu, 0x0000u, 0x0000u);
                    } else {
                        return select_edge(k, 0x1901u, 0x0000u, 0x0000u, 0x0000u);
                    }
                }
            }
        }
    }
    return 0;
}
uint8_t route_slot(uint8_t src, uint8_t dst) {
    uint32_t a, b, c, row;
    uint8_t i = (uint8_t)(dst - 1u);
        if (src <= 18u) {
            if (src <= 9u) {
                if (src <= 5u) {
                    if (src <= 3u) {
                        if (src <= 2u) {
                            if (src <= 1u) {
                                a = 0x5A555DB8u;
                                b = 0x59555555u;
                                c = 0x00000026u;
                            } else {
                                a = 0x00000000u;
                                b = 0x00000000u;
                                c = 0x00000000u;
                            }
                        } else {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        }
                    } else {
                        if (src <= 4u) {
                            a = 0x6A555511u;
                            b = 0x69955555u;
                            c = 0x0000006Au;
                        } else {
                            a = 0x95A69000u;
                            b = 0xA6AAAAAAu;
                            c = 0x00000019u;
                        }
                    }
                } else {
                    if (src <= 7u) {
                        if (src <= 6u) {
                            a = 0x55555145u;
                            b = 0x55555555u;
                            c = 0x00000055u;
                        } else {
                            a = 0x2A040000u;
                            b = 0x28000000u;
                            c = 0x0000002Au;
                        }
                    } else {
                        if (src <= 8u) {
                            a = 0x80510000u;
                            b = 0xA2AAAA96u;
                            c = 0x00000028u;
                        } else {
                            a = 0x00400000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        }
                    }
                }
            } else {
                if (src <= 14u) {
                    if (src <= 12u) {
                        if (src <= 11u) {
                            if (src <= 10u) {
                                a = 0x00000000u;
                                b = 0x00000000u;
                                c = 0x00000000u;
                            } else {
                                a = 0x00410000u;
                                b = 0x00000028u;
                                c = 0x00000000u;
                            }
                        } else {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        }
                    } else {
                        if (src <= 13u) {
                            a = 0x00000000u;
                            b = 0x54400000u;
                            c = 0x00000015u;
                        } else {
                            a = 0x505559AAu;
                            b = 0x41155555u;
                            c = 0x00000080u;
                        }
                    }
                } else {
                    if (src <= 16u) {
                        if (src <= 15u) {
                            a = 0x40555511u;
                            b = 0x41155555u;
                            c = 0x00000040u;
                        } else {
                            a = 0x15555555u;
                            b = 0x55555554u;
                            c = 0x00000055u;
                        }
                    } else {
                        if (src <= 17u) {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        } else {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        }
                    }
                }
            }
        } else {
            if (src <= 27u) {
                if (src <= 23u) {
                    if (src <= 21u) {
                        if (src <= 20u) {
                            if (src <= 19u) {
                                a = 0x55555555u;
                                b = 0x55555541u;
                                c = 0x00000055u;
                            } else {
                                a = 0x95555555u;
                                b = 0xA6AAA816u;
                                c = 0x00000069u;
                            }
                        } else {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        }
                    } else {
                        if (src <= 22u) {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        } else {
                            a = 0x2AAAAAAAu;
                            b = 0xAAA986A8u;
                            c = 0x000000AAu;
                        }
                    }
                } else {
                    if (src <= 25u) {
                        if (src <= 24u) {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        } else {
                            a = 0x55555555u;
                            b = 0x55545155u;
                            c = 0x00000055u;
                        }
                    } else {
                        if (src <= 26u) {
                            a = 0x15555555u;
                            b = 0x55504154u;
                            c = 0x00000055u;
                        } else {
                            a = 0x95555555u;
                            b = 0xAA8A2956u;
                            c = 0x0000006Au;
                        }
                    }
                }
            } else {
                if (src <= 32u) {
                    if (src <= 30u) {
                        if (src <= 29u) {
                            if (src <= 28u) {
                                a = 0x40555511u;
                                b = 0x41155555u;
                                c = 0x00000040u;
                            } else {
                                a = 0x15555555u;
                                b = 0xA8904154u;
                                c = 0x0000006Au;
                            }
                        } else {
                            a = 0x95555555u;
                            b = 0xA2AAA956u;
                            c = 0x00000068u;
                        }
                    } else {
                        if (src <= 31u) {
                            a = 0x2A082088u;
                            b = 0x08000000u;
                            c = 0x00000026u;
                        } else {
                            a = 0x01000000u;
                            b = 0x14400000u;
                            c = 0x00000015u;
                        }
                    }
                } else {
                    if (src <= 34u) {
                        if (src <= 33u) {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        } else {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        }
                    } else {
                        if (src <= 35u) {
                            a = 0x40514000u;
                            b = 0x51555555u;
                            c = 0x00000004u;
                        } else {
                            a = 0x00000000u;
                            b = 0x00000000u;
                            c = 0x00000000u;
                        }
                    }
                }
            }
        }
    if (i < 16u) row = a;
    else if (i < 32u) row = b;
    else row = c;
    return (uint8_t)((row >> ((i & 15u) << 1)) & 3u);
}
static __attribute__((noinline)) uint16_t edge_ws(uint8_t src, uint8_t dst) {
    return get_edge(src, route_slot(src, dst));
}

// ##############################################

// main function
int main(int argc, char const *argv[]) {

    #ifdef __linux__

        if (argc < 4) {
            _put_str("usage: ./Path_Planner_Dec <current_node> <next_node> <is_encrypted>\n");
            _put_str("       current_node     : where the bot is, e.g. 35 (the start box)\n");
            _put_str("       is_encrypted = 0 : next_node is a node number, e.g. 7\n");
            _put_str("       is_encrypted = 1 : next_node is the encrypted code, 16 hex digits\n");
            return 1;
        }
        uint8_t  CURRENT_NODE        = atoi(argv[1]);
        uint8_t  IS_ENCRYPTED        = atoi(argv[3]);
        uint8_t  NEXT_NODE           = 0;
        uint32_t ENCRYPTED_HI        = 0;
        uint32_t ENCRYPTED_LO        = 0;
        if (IS_ENCRYPTED) {
            if (!read_block(argv[2], &ENCRYPTED_HI, &ENCRYPTED_LO)) {
                _put_str("with is_encrypted = 1, next_node must be exactly 16 hex digits\n");
                return 1;
            }
        }
        else {
            NEXT_NODE = atoi(argv[2]);
        }
        uint8_t MESSAGE_0           = 0;
        uint8_t MESSAGE_1           = 0;
        uint8_t MESSAGE_2           = 0;
        uint8_t MESSAGE_3           = 0;
        uint8_t MESSAGE_4           = 0;
        uint8_t NODE_POINT          = 0;
        uint8_t CPU_DONE            = 0;

    #else
        // Address value of variables are updated for RISC-V Implementation
        // inputs: 0x02000000 .. 0x0200000F
        #define ENCRYPTED_HI        (* (volatile uint32_t * ) 0x02000000)
        #define ENCRYPTED_LO        (* (volatile uint32_t * ) 0x02000004)
        #define IS_ENCRYPTED        (* (volatile uint8_t  * ) 0x02000008)
        #define NEXT_NODE           (* (volatile uint8_t  * ) 0x0200000c)
        #define CURRENT_NODE        (* (volatile uint8_t  * ) 0x0200000d)
        // outputs: 0x02000010 .. 0x0200001F
        #define MESSAGE_0           (* (volatile uint8_t  * ) 0x02000010)
        #define MESSAGE_1           (* (volatile uint8_t  * ) 0x02000011)
        #define MESSAGE_2           (* (volatile uint8_t  * ) 0x02000012)
        #define MESSAGE_3           (* (volatile uint8_t  * ) 0x02000013)
        #define MESSAGE_4           (* (volatile uint8_t  * ) 0x02000014)
        #define NODE_POINT          (* (volatile uint8_t  * ) 0x02000018)
        #define CPU_DONE            (* (volatile uint8_t  * ) 0x0200001c)

    #endif

    // read once here: for the next run, the program may write IS_ENCRYPTED = 0
    uint8_t is_encrypted = IS_ENCRYPTED;

    // the message: bytes 1..5 of the decrypted block (0x00 = no character)
    uint8_t message[5] = { 0, 0, 0, 0, 0 };

    // array to store the planned path
    uint8_t path_planned[40];
    // index to keep track of the path_planned array
    uint8_t idx = 0;

    uint8_t start_point = CURRENT_NODE;   // where the bot is
    uint8_t end_point   = 0;              // where the bot goes

    // ############# Add your code here #############
    if (start_point < 1u || start_point > 36u) return 1;

    if (is_encrypted) {
        wr32(path_planned, ENCRYPTED_HI);
        wr32(path_planned + 4, ENCRYPTED_LO);
        wr32(path_planned + 8, 0x396CEC47u);
        path_planned[12] = 0xD0u;
        path_planned[13] = 0x21u;
        path_planned[14] = 0x35u;
        path_planned[15] = 0x60u;
        path_planned[16] = 0x08u;
        path_planned[17] = 0xD5u;
        decrypt_ws(path_planned);
        uint8_t done = path_planned[3];
        *(volatile uint8_t *)&path_planned[14] = path_planned[2];
        *(volatile uint8_t *)&path_planned[15] = path_planned[1];
        *(volatile uint8_t *)&path_planned[16] = path_planned[0];
        *(volatile uint8_t *)&path_planned[17] = path_planned[7];
        *(volatile uint8_t *)&path_planned[18] = path_planned[6];
        *(volatile uint8_t *)&path_planned[0] = CURRENT_NODE;
        end_point = path_planned[4];

        if (done > 1u || end_point < 1u || end_point > 36u) return 1;
        if (!done) {
            uint8_t next = path_planned[5];
            if (next < 1u || next > 36u) return 1;
            IS_ENCRYPTED = 0;
            NEXT_NODE = next;
        }
        path_planned[13] = (uint8_t)(end_point | 0x40u | (done << 7));
    } else {
        end_point = NEXT_NODE;
        if (end_point < 1u || end_point > 36u) return 1;
        path_planned[13] = end_point;
        *(volatile uint8_t *)&path_planned[0] = start_point;
    }

    uint16_t e;

    if (*(volatile uint8_t *)&path_planned[0] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 1u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[0], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[1] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[1] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 2u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[1], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[2] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[2] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 3u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[2], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[3] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[3] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 4u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[3], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[4] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[4] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 5u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[4], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[5] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[5] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 6u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[5], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[6] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[6] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 7u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[6], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[7] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[7] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 8u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[7], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[8] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[8] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 9u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[8], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[9] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[9] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 10u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[9], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[10] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[10] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 11u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[10], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[11] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[11] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 12u;
        goto route_complete;
    }
    e = edge_ws(*(volatile uint8_t *)&path_planned[11], (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u));
    if (!e) return 1;
    *(volatile uint8_t *)&path_planned[12] = (uint8_t)(e & 63u);

    if (*(volatile uint8_t *)&path_planned[12] == (uint8_t)(*(volatile uint8_t *)&path_planned[13] & 63u)) {
        idx = 13u;
        goto route_complete;
    }
    return 1;
route_complete:
    is_encrypted = (uint8_t)((path_planned[13] >> 6) & 1u);
    if (is_encrypted) {
        message[0] = path_planned[14];
        message[1] = path_planned[15];
        message[2] = path_planned[16];
        message[3] = path_planned[17];
        message[4] = path_planned[18];
    }
    if (is_encrypted && !(path_planned[13] & 0x80u)) CURRENT_NODE = (uint8_t)(path_planned[13] & 63u);
    // ##############################################

    // the message bytes are written into data memory (encrypted block only).
    if (is_encrypted) {
        MESSAGE_0 = message[0];
        MESSAGE_1 = message[1];
        MESSAGE_2 = message[2];
        MESSAGE_3 = message[3];
        MESSAGE_4 = message[4];
    }
    // the node values are written into data memory sequentially.
    for (int i = 0; i < idx; ++i) {
        NODE_POINT = path_planned[i];
    }
    // Path Planning Computation Done Flag
    CPU_DONE = 1;

    #ifdef __linux__    // for host pc: the output test.sh reads (see "Output (PC)" at the top)

        if (is_encrypted) {
            _put_str("Message : ");
            for (int i = 0; i < 5; ++i) {
                if (message[i]) _put_byte(message[i]);
            }
            _put_byte('\n');
        }
        for (int i = 0; i < idx; ++i) {
            _put_value(path_planned[i]);
        }
        if (is_encrypted) {
            if (IS_ENCRYPTED == 0) {            // the inputs written for the next run
                _put_str("Next current_node : ");
                _put_value(CURRENT_NODE);
                _put_str("Next next_node : ");
                _put_value(NEXT_NODE);
            }
            else {
                _put_str("Done\n");
            }
        }

    #endif

    return 0;
}
