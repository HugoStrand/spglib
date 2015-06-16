#!/usr/bin/env ruby
#   Copyright (C) 2008 Atsushi Togo
#   togo.atsushi@gmail.com
# 
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to
#   the Free Software Foundation, Inc., 51 Franklin Street,
#   Fifth Floor, Boston, MA 02110-1301, USA, or see
#   http://www.gnu.org/copyleft/gpl.html
#
# Usage: symPoscar.rb [OPTION] [structure]
# OPTION: -s, --symprec= : Symmetry check precision

require 'optparse'
require 'getspg.so'
require 'poscar'
include Getspg

spg2hall = [0,
            1,   2,   3,   6,   9,  18,  21,  30,  39,  57,
            60,  63,  72,  81,  90, 108, 109, 112, 115, 116,
            119, 122, 123, 124, 125, 128, 134, 137, 143, 149,
            155, 161, 164, 170, 173, 176, 182, 185, 191, 197,
            203, 209, 212, 215, 218, 221, 227, 228, 230, 233,
            239, 245, 251, 257, 263, 266, 269, 275, 278, 284,
            290, 292, 298, 304, 310, 313, 316, 322, 334, 335,
            337, 338, 341, 343, 349, 350, 351, 352, 353, 354,
            355, 356, 357, 358, 359, 361, 363, 364, 366, 367,
            368, 369, 370, 371, 372, 373, 374, 375, 376, 377,
            378, 379, 380, 381, 382, 383, 384, 385, 386, 387,
            388, 389, 390, 391, 392, 393, 394, 395, 396, 397,
            398, 399, 400, 401, 402, 404, 406, 407, 408, 410,
            412, 413, 414, 416, 418, 419, 420, 422, 424, 425,
            426, 428, 430, 431, 432, 433, 435, 436, 438, 439,
            440, 441, 442, 443, 444, 446, 447, 448, 449, 450,
            452, 454, 455, 456, 457, 458, 460, 462, 463, 464,
            465, 466, 467, 468, 469, 470, 471, 472, 473, 474,
            475, 476, 477, 478, 479, 480, 481, 482, 483, 484,
            485, 486, 487, 488, 489, 490, 491, 492, 493, 494,
            495, 497, 498, 500, 501, 502, 503, 504, 505, 506,
            507, 508, 509, 510, 511, 512, 513, 514, 515, 516,
            517, 518, 520, 521, 523, 524, 525, 527, 529, 530,
            531]

symprec = 1e-5
hall_number = 0
angle_tolerance = -1.0
nonewline = false
pos_shift = [0,0,0]
shift_string = false
is_long_output = false
is_operations = false
is_dataset = false
is_check_settings = false
opt = OptionParser.new
opt.on('-s', '--symprec VALUE', 'Symmetry check precision') {|tmp| symprec = tmp.to_f}
opt.on('-a', '--angle_tolerance VALUE', 'Symmetry check precision for angle between lattice vectors in degrees') {|tmp| angle_tolerance = tmp.to_f}
opt.on('--shift VALUE', 'uniform shift of internal atomic positions') {|tmp| shift_string = tmp}
opt.on('-n', '--nonewline', 'Do not output the trailing newline') {nonewline = true}
opt.on('-l', '--long', 'Long output') {is_long_output = true}
opt.on('-o', '--operations', 'Symmetry operations') {is_operations = true}
opt.on('-d', '--dataset', 'Dataset') {is_dataset = true}
opt.on('--settings', 'Check all settings') {is_check_settings = true}
opt.on('--hall VALUE', 'Hall symbol by the numbering') {|tmp| hall_number = tmp.to_i}
opt.parse!(ARGV)

if shift_string
  pos_shift = []
  shift_string.split.each {|val| pos_shift << val.to_f }
end
cell = Vasp::Poscar.new(ARGV.shift).cell
lattice = cell.axis.transpose
names = (cell.atoms.collect {|atom| atom.name}).uniq
position = []
types = []
names.each_with_index do |name, i|
  cell.atoms.each do |atom|
    if atom.name == name
      apos = atom.position
      position << [ apos[0]+pos_shift[0],
                    apos[1]+pos_shift[1],
                    apos[2]+pos_shift[2] ]
      types << i+1
    end
  end
end

dataset = get_dataset(lattice,
                      position,
                      types,
                      hall_number,
                      symprec,
                      angle_tolerance)
spgnum, spg, hallnum, hall_symbol, setting, t_mat, o_shift,
rotations, translations, wyckoffs,
brv_lattice, brv_types, brv_positions = dataset
ptg_symbol, ptg_num, trans_mat = getptg(rotations)

if spgnum > 0 and not is_check_settings
  if nonewline
    print "#{spg.strip} (#{spgnum})"
  else
    puts "#{spg.strip} (#{spgnum}) / #{ptg_symbol} / #{hall_symbol.strip} (#{hallnum}) / #{setting}"

    if is_long_output
      puts "----------- original -----------"
      lattice.each do |vec|
        printf("%10.5f %10.5f %10.5f\n", vec[0], vec[1], vec[2]);
      end

      puts "------------ final -------------"
      brv_lattice.each do |vec|
        printf("%10.5f %10.5f %10.5f\n", vec[0], vec[1], vec[2]);
      end

      brv_types.size.times do |i|
        printf("%d: %d  %10.5f %10.5f %10.5f\n", i+1, brv_types[i], 
               brv_positions[i][0], brv_positions[i][1], brv_positions[i][2]);
      end
    end

    if is_dataset
      puts "------ transformation matrix -----"
      t_mat.each do |row|
        printf("%10.5f %10.5f %10.5f\n", row[0], row[1], row[2]);
      end

      puts "---------- origin shift ----------"
      printf("%10.5f %10.5f %10.5f\n", o_shift[0], o_shift[1], o_shift[2]);
      
      puts "--------- Wyckoff position ----------"
      wl = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
      wyckoffs.each_with_index do |w, i|
        pos = []
        3.times do |j|
          pos.push( position[i][j] - position[i][j].floor )
        end
        printf("%4d %2s  %s %8.5f %8.5f %8.5f\n",
               i+1, cell.atoms[i].name, wl[w,1], pos[0], pos[1], pos[2])
      end
    end

  end
end

if is_operations or is_dataset
  rotations.size.times do |i|
    print "----", i+1, "----\n"
    rotations[i].each do |row|
      printf("%2d %2d %2d\n", row[0], row[1], row[2])
    end
    printf("%f %f %f\n", translations[i][0], translations[i][1], translations[i][2])
  end
end

if is_check_settings
  num_settings = spg2hall[spgnum + 1] - spg2hall[spgnum]
  puts
  puts "There are #{num_settings} settings."
  num_settings.times {|i|
    spgnum, spg, hallnum, hall_symbol, setting, t_mat, o_shift,
    rotations, translations, wyckoffs = get_dataset(lattice,
                                                    position,
                                                    types,
                                                    spg2hall[spgnum] + i,
                                                    symprec,
                                                    angle_tolerance)
    puts "#{i + 1}: #{spg.strip} (#{spgnum}) / #{ptg_symbol} / #{hall_symbol.strip} (#{hallnum}) / #{setting}"
  }
end

