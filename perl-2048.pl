#!/usr/bin/perl
use strict;
use warnings;

#V 1.1013 Solid Peformance, timers working OK. Everything seems like it checks out
#1.1072.1.2 OK Before AI
#1.1072.1.13 OK Passing Array vars to routines
#1.1072.1.154 working version of AI
#1.1072.1.371 Very good version of AutoPlay

use Text::ANSITable;
use Data::Dumper;
use Switch;
use Term::ANSIScreen qw(cls);
use Term::ReadKey;
my $clear_screen = cls();

##DEBUG
$Data::Dumper::Indent = 3;       # pretty print with array indices
$Data::Dumper::Pair = " => ";
my $DEBUG = 0;
my $DEBUG_counter = 0;

#GRID SIZE
my $square_size = 4;
my $arr_size = ($square_size * $square_size) - 1;

#CONTROL
my $counter = 0; #used to track current shift pattern and whether to spawn tile
my $last_counter = 0;
my $two_odds = 50; #percentage of twos on tile spawn

##BRING UP PLAYING AREA VARIABLES
my %place ; #hash used to hold references for all variations of tiles for grid 
my @b; #array holding current tiles , used throughout

##INTERACTIVE PLAY
my $init_start_tiles = 2;
my $lastmove_num = 0;
my $max_undo = 5;
my @undo;
my @redo;

##AutoPlay
my $start_autoplay = 0;
my $ai_type = 2;
my $dynamic_autofoward = 1;
my $min_autoforward = 4;
my $keep_num = 10;
my $auto_count = 0;
my @tracking; #autoplay hash
my $corner = 'r_row'; #row r_row col r_col
my $direction = 'down'; #up down
my $no_random_spawn = 0; #IF enabled, boring but highest score
if($no_random_spawn == 1) { $two_odds = 100; } #if we're going all out... just turn off all the random spawning
if($no_random_spawn == 1) { $init_start_tiles = 1 } #Also setting start tiles to 1
my $human_moves_per_minute = 68;
my $auto_forward;


##PLAY COUNTERS
my $move_counter;
my $nomove_counter;
my $score;
my $begin_time ; #start time on init_table
my $time_diff ; #time difference in seconds

&init_table;

#&test_ranking;
#exit;



if($start_autoplay) {
   &exec_autoplay;
}

while (1) {
   $DEBUG_counter++;
   my $keypress;
   print $clear_screen;
   $time_diff = time() - $begin_time;
   &arr_out(@b);
   if($#undo < 0) { push(@undo,[@b]); }

   #GAME OVER
   if ((&count_free(@b) == 0) and (&moves_free(@b) == 0)) {
      &game_over("aaand done... GAME OVER :-(")
   } 

   my ($tiles,$highest,$total) = &board_stats(@b);

   #IN GAME STATUS
   print "DEBUG CNT: $DEBUG_counter\n\n" if ($DEBUG > 2);
   print "Press:\n";
   print "           (k) up            \n ";
   print "(h) left            (l) right\n";
   print "           (j) down          \n";
   print "---------------------------------------------\n";
   print "(u) Undo (r) Redo\n";
   print "(R) Restart Game (q) to Quit\n";
   print "(A) AutoSolve\n";
   print "---------------------------------------------\n";
   print "\n";
   print "*********************************************\n";
   print "SCORE: $score\t";
   print "Last move #: $lastmove_num \t" if($DEBUG);
   print "Move Counter: $move_counter\t" ;
   print "Timer:$time_diff\t" ;
   print "NO Move Counter: $nomove_counter\t" if($DEBUG);
   print "Undo Count: " . int($#undo + 1) . "\t" if($DEBUG);
   print "Total Tiles: $tiles" . "\t" ;
   print "Highest Tile: $highest " . "\t" ;
   print "Counter: $last_counter " . "\t" ;
   print "\n";
   print "*********************************************\n";

   $keypress = &readkey;
   if ($keypress eq 'q') { &game_over("Quitter!") ; } else { $lastmove_num = &move_tiles($keypress); }
   $last_counter = $counter;
   $counter = 0; #reset counter
}

sub exec_autoplay {
   &arr_out(@b);
   until ((&count_free(@b) == 0) and (&moves_free(@b) == 0)) {
      my $cnt_free = &count_free(@b); 
      my $perc_free = int($cnt_free / ($square_size ** 2) * 100) ;

      if($dynamic_autofoward) {
         $auto_forward = abs(9 - int(sqrt($perc_free))) + 1;
         if($auto_forward < $min_autoforward) { $auto_forward = $min_autoforward; }
      } else {
         $auto_forward = $min_autoforward;
      }
      $time_diff = time() - $begin_time;
      print "AutoForward:$auto_forward\t"; 
      print "Score: $score\t"; 
      print "Moves: $move_counter\t"; 
      print "Time: " . &duration($time_diff) . "\t"; 
      print "\n"; 
      @b = &autoplay($ai_type,\@b);
      &arr_out(@b);
   }

   &game_over("aaand done... GAME OVER :-(");
   exit;
}



sub game_over {
   my $msg = shift;
   print $msg . "\n";
   print "Final Score: $score\n";
   print "Move Count:$move_counter\n";
   print "Playing Time: " . &duration($time_diff) . "\n";
   if($time_diff <= 0) {
      print "Moves per minute: N/A\n";
   } else {
      print "Moves per minute: " . int($move_counter / ($time_diff / 60)) . "\n";
   }
   print "Human Time: " . &duration(int($move_counter / $human_moves_per_minute) * 60) . "\n";
   exit;
}

sub duration {
   my $dur = shift;
   my $orig_dur = $dur;


   my $retval = '';

   my $seconds = $dur % 60;
   $seconds = sprintf("%02d",$seconds );
   $dur += -$seconds;
   my $minute = ($dur / 60) % 60;
   $minute = sprintf("%02d",$minute);
   $dur += -$minute * 60;
   my $hour = ($dur / 60) / 60;
   $hour = sprintf("%02d",$hour);
   $dur += -$hour * 60 * 60;

   if($hour > 0) { $retval .= "$hour hrs "; }
   if($minute > 0) { $retval .= "$minute minute(s) "; }
   if($seconds > 0) { $retval .= "$seconds seconds(s)"; }

   return $retval;
}

sub moves_free {
   my @working = @_;
   my $cnt = 0;
   $cnt += &check_combine(\@b,'row');
   $cnt += &check_combine(\@b,'col');
   print "Moves Free: $cnt \n" if ($DEBUG);
   return $cnt;
}

sub count_free {
   my @working = @_;
   my $cnt = 0;
   foreach(0 .. $arr_size) {
      $cnt++ if($working[$_] == 0);
   }
   print "Count Free: $cnt \n" if ($DEBUG);
   return $cnt;
}

sub board_stats {
   my @working = @_;
   my $tiles = 0;
   my $highest = 0;
   my $total = 0;

   foreach(@working) {
      if($_ > $highest) { $highest = $_; }
      if($_ != 0) { $tiles++; }
      $total += $_;
   }
   return ($tiles,$highest,$total);
}

sub spawn_tile {
   my $aref = shift;
   my $tile = shift;
   my @b = @{$aref};
   my $p;

   if(!defined($tile)) { $tile = &flip; }

   if(&count_free(@b) == 0) { print "No more free tiles!\n" if ($DEBUG); return @b; }
   
   my $cnt = 0;
   
   my @rsort = reverse &sort_order;

   while(1) {
      if($no_random_spawn) {
         $p = $rsort[$cnt];
         $cnt++;
      } else {
         $p = &r;
      }

      if($b[$p] == 0) { $b[$p] = $tile; last;}
   }
   return @b;
}

sub init_table {
   $move_counter = 0;
   $nomove_counter = 0;
   $score = 0;
   $begin_time = time() ;
   my $r;
   my @board;
   my $debug = shift;

   ##BRING UP PLAYING AREA
   foreach(0 .. $arr_size) {
      $board[$_] = $_;
      $place{$_}{r} = int(($_ % $square_size) + 1) ;
      $place{$_}{c} = int(($_ / $square_size) + 1) ;
   }

   
   foreach(1 .. $square_size ) {
      my $p = $_;
      $place{'row'}{$p} = [];
      $place{'col'}{$p} = [];
      $place{'r_row'}{$p} = [];
      $place{'r_col'}{$p} = [];
      foreach(@board) {
         if($place{$_}{r} == $p) {
            push($place{'row'}{$p},$_);
            unshift($place{'r_row'}{$p},$_);
         }
         
         if($place{$_}{c} == $p) {
            push($place{'col'}{$p},$_);
            unshift($place{'r_col'}{$p},$_);
         }
      }
   }

   ##INIT PIECES
   if(($debug)) {
      foreach(0 .. $arr_size - 1) { $r = $_; $b[$r] = '2'; } 
      $b[$arr_size] = $b[$arr_size] * 2;
      return;
   }

   foreach(0 .. $arr_size) { $r = $_; $b[$r] = 0; } 
   foreach(1 .. $init_start_tiles) { @b = &spawn_tile(\@b); }


}

sub move_tiles {
   my $key = shift;
   my ($axis,$shift);
   switch ($key) {
      case "l"  {
         print "Right\n";
         $counter += &check_shift(\@b,'r_col');
         $counter += &check_combine(\@b,'r_col');
         @b = &shift_tiles(\@b,'r_col');
      } case "h"  {
         print "Left\n";
         $counter += &check_shift(\@b,'col');
         $counter += &check_combine(\@b,'col');
         @b = &shift_tiles(\@b,'col');
      } case "j"  {
         print "Down\n";
         $counter += &check_shift(\@b,'r_row');
         $counter += &check_combine(\@b,'r_row');
         @b = &shift_tiles(\@b,'r_row');
      } case "k"  {
         print "Up\n";
         $counter += &check_shift(\@b,'row');
         $counter += &check_combine(\@b,'row');
         @b = &shift_tiles(\@b,'row');
      } case "R"  {
         print "RESTART\n";
         &init_table;
         $counter = -99;
      } case "A"  {
         print "AutoPlay\n";
         &exec_autoplay;
         $counter = 1;
      } case "u"  {
         print "UNDO\n";
         &undo;
         $counter = -99;
      } case "r"  {
         print "REDO\n";
         &redo;
         $counter = -99;
      } case "D"  {
         print "DEBUG\n";
         &init_table(1);
         $counter = -99;
      } else    {
         print "Invalid Selection\n";
         $counter = -99;
      }
   }


   if($counter > 0) {
      if(&count_free(@b) > 0) { $move_counter++; @b = &spawn_tile(\@b); push(@undo,[@b]); }
   } else {
      $nomove_counter++;
      print "NO MOVEMENT!\n" if ($DEBUG);
   }
   return $counter;
}

sub undo {
   if($#undo >= 0) {
      my $working_undo = pop(@undo);
      push(@redo,$working_undo);
      @b = @{$working_undo};
   }
}

sub redo {
   if($#redo >= 0) {
      my $working_undo = pop(@redo);
      push(@undo,$working_undo);
      @b = @{$working_undo};
   }
   return 0;

}

sub split_move {
   my $aref = shift;
   my @b = @{$aref};
   my $tile = shift;
   my $score_a;
   my $score_b;
   my $score_diff;

   my @control = qw/row r_row col r_col/;

   my %tmp_track; #tracking hash
   my %score;

   foreach(@control) {
      my @tmp;
      my $cnt = 0;

      $cnt += &check_shift(\@b,$_);
      $cnt += &check_combine(\@b,$_);

      if($cnt > 0) {
         $score_a = $score;
         @tmp = &shift_tiles(\@b,$_);
         $score_b = $score;
         $score_diff = $score_b - $score_a;

         @tmp = &spawn_tile(\@tmp,$tile); 
         $tmp_track{$_} = [@tmp];
         $score{$_} = $score_diff;
      } 
   }
   return \%tmp_track,\%score;
}

sub test_play {
   my $aref = shift;
   my @b = @{$aref};
   my $tile = shift;
   my $depth = shift;
   my $parent;
   my $tmp_track;
   my $score;

   if($depth == 1) {
      $parent = 'none';
      ($tmp_track,$score) = &split_move(\@b,$tile);
      while((my($u,$val))=each(%{$tmp_track})) { 
         my $ns = $$score{$u} ;
         push(@tracking, { depth => $depth, parent => $parent, arg => $u , prod => [@{$val}] , score => $ns });
      }
   } else {
      for(my $z = 0; $z <= $#tracking; $z++) {
         if(defined($tracking[$z])) {
            my %h = %{$tracking[$z]}; #get hash in arry
            if($h{depth} == $depth - 1) { #grab items with depth 1 below us
               my @arr = @{$h{prod}}; #copy array
               ($tmp_track,$score) = &split_move(\@arr,$tile); #split this array and push product
               while((my($u,$val))=each(%{$tmp_track})) { 
                  my $ns = $$score{$u} ;
                  push(@tracking, { depth => $depth, parent => $z, arg => $u , prod => [@{$val}] , score => $ns } );
               }
            }
         }
      }
   }
}


sub sort_order {
   my @sort_order;
   my $x; #NEW
   for(my $z = $square_size; $z >= 0; $z--) {
      my @tmp;
      next if $z == 0;
      if($direction eq 'up') {
         @tmp = reverse @{$place{$corner}{$z}};
      } else {
         @tmp = @{$place{$corner}{$z}};
      }
      push(@sort_order,@tmp);
   }
   return @sort_order;
}

sub autoplay {
   #Grab top X from depth
   #trash the rest
   
   
   my $ai_type = shift;
   $move_counter += $auto_forward;


   my $aref = shift;
   my @b = @{$aref};

   @tracking = ();
   my @tiles = ();
   my $score_a = $score;

   my @sort_order = &sort_order;


   #get random tiles
   foreach(1 ..$auto_forward) {
      push(@tiles,&flip);
   }

   for (my $depth = 1; $depth <= $#tiles + 1; $depth++) {
      my $t = $tiles[$depth - 1];
      &test_play(\@b,$t,$depth);

      ##EXPERIMENT
      if($ai_type == 3) {
         my %htot;
         for(my $z = 0; $z <= $#tracking; $z++) {
            if(defined($tracking[$z])) {
               my %h = %{$tracking[$z]};
               if($h{depth} == $depth ) {
                  $htot{$z}{rank} = &arr_rank(\@sort_order,\@{$h{prod}});
                  $htot{$z}{depth} = $depth;
               }
            }
         }
   
         my @keep;
         foreach my $l (reverse sort {$htot{$a}{rank} <=> $htot{$b}{rank}} keys %htot) { 
            #last if (($htot{$l}{rank} eq 0) and ($#keep >= 0));
            push(@keep,$l);
            #print "d:$htot{$l}{depth} r:$htot{$l}{rank} k:$l\n";
            last if ($#keep + 1 >= $keep_num);
         }
   
         for(my $z = 0; $z <= $#tracking; $z++) {
            if(defined($tracking[$z])) {
               my %h = %{$tracking[$z]};
               if($h{depth} == $depth ) {
                  if (grep { $z eq $_ } @keep ) {
                     print "";
                  } else {
                     delete $tracking[$z];
                  }
               }
            }
         }
      }
      $ai_type = 2;
   }



   my $match = 0;

   if($ai_type == 1) {
      my $low_tiles = 2**32;
      my $high_total = 0;
      my $match = 0;
   
      for(my $z = 0; $z <= $#tracking; $z++) {
         my %h = %{$tracking[$z]};
         if($h{depth} == $auto_forward) {
            my ($tiles,$highest,$total) = &board_stats(@{$h{prod}});
            if( $tiles < $low_tiles ) {
                  $low_tiles = $tiles;
                  $match = $z;
            }
         }
      }
      print "Match: $match h:$high_total t:$low_tiles\n";
   } elsif($ai_type == 2) {
      my $lowest = 0;
      my $total ;

      for(my $z = 0; $z <= $#tracking; $z++) {
         if(defined($tracking[$z])) {
            my %h = %{$tracking[$z]};
            if($h{depth} == $auto_forward) {
               $total = &arr_rank(\@sort_order,\@{$h{prod}});
               if($total > $lowest) { $lowest = $total; $match = $z; }
            }
         }
      }
      print "Match: $match h:$lowest\n";
   }

   my @move_sequence;
   my %ms = %{$tracking[$match]};
   my $parent = $ms{parent};

   unshift(@move_sequence,$match);
   unshift(@move_sequence,$parent);

   until ($parent eq 'none') {
      $parent = $tracking[$parent]->{parent} ;
      unshift(@move_sequence,$parent);
   }

   shift(@move_sequence);

   my $score_add = 0;
   foreach(@move_sequence) { $score_add += $tracking[$_]->{score}; }
   $score = $score_a + $score_add;

   return @{$tracking[$match]{prod}};
}

sub arr_rank {
   my $control = shift;
   my $data = shift;

   my @ctl = @{$control};
   my @dat = @{$data};

   my %comp;
   my $adder = 0;

   for(my $z = 0; $z <= $#dat ; $z++) {
      $comp{$z + 1}{dat} = $dat[$ctl[$z]];
      $comp{$z + 1}{ctl} = $ctl[$z];
   }

   my $x = $square_size + 1;
   foreach my $l (sort { $a <=> $b or $comp{$a}{dat} <=> $comp{$b}{dat} } keys %comp) {
      my $mod = $l % $square_size;
      $x-- if($mod == 1);


      #my $tmp = 2**($x * ($x + 1)); #column 4 .. 1
      #my $tmp3 = (2**$tmp2) * $comp{$l}{dat};
      
      my $sq = (($square_size**2) + 1 - $l)  ; #16 .. 1
      my $val = $comp{$l}{dat};

      my $m = (3**($sq * .1 * $x) * $val);
      #my $m = int((2**($sq + (.2 * $val)) ** $x)); #errrr

      #$adder += (($square_size**2) + 1 - $l) ** $comp{$l}{dat} ; #next the rank in the column times the tile value
      #$adder += ((($square_size**2) + 1 - $l) * $comp{$l}{dat}) ; #next the rank in the column times the tile value

      if( $comp{$l}{dat} != 0 ) {
         $adder += $m;
         #first we want the column to be a priority
         #$adder += $tmp; #column priority
         #$adder += $tmp2; #first we want the column to be a priority
         #$adder += $tmp3; #tile value priority
      }
      #print "k: $l d:$comp{$l}{dat} => c:$comp{$l}{ctl} add:$adder mod:$mod x:$x tmp:$tmp tmp2:$tmp2 tmp3:$tmp3\n" if($DEBUG);
      print "k: $l d:$comp{$l}{dat} => c:$comp{$l}{ctl} add:$adder mod:$mod x:$x m:$m \n" if($DEBUG);

   }
   return $adder;
}

sub check_shift {
   my $aref = shift;
   my $mv = shift;
   my $check_num = 0;
   my @b = @{$aref};
   while((my($u,$val))=each(%{$place{$mv}})) { 
      my @tmp = @$val;
      my $ph = 0;
      for(my $z = 0; $z <=$#tmp; $z++) {
         if($b[$tmp[$z]] == 0) { $ph++; next; } 
         if ($ph != 0) { $check_num++; }
      }
   }
   return $check_num;
}

sub check_combine {
   my $aref = shift;
   my $mv = shift;
   my $check_num = 0;
   my @b = @{$aref};
   while((my($u,$val))=each(%{$place{$mv}})) { 
      my @tmp = @$val;
      my $last_moved = '-1';
      for(my $z = 0; $z <=$#tmp; $z++) {
         if($b[$tmp[$z]] == 0) { next; }
         if($z + 1 > $#tmp) { next; }
         if($tmp[$z] == $last_moved) { next; }
         if( $b[$tmp[$z]] eq $b[$tmp[$z + 1]]) {
            $check_num++;
            $last_moved = $tmp[$z+1];
         }
      }
   }
   return $check_num;
}

sub combine_tiles {
   my $aref = shift;
   my $mv = shift;
   my @b = @{$aref};

   while((my($u,$val))=each(%{$place{$mv}})) { 
      my @tmp = @$val;
      #COMBINE TILES
      my $last_moved = '-1';
      for(my $z = 0; $z <=$#tmp; $z++) {
         my $note = '';

         if($b[$tmp[$z]] == 0) { next; }
         if($z + 1 > $#tmp) { next; }
         if($tmp[$z] == $last_moved) { next; }

         if( $b[$tmp[$z]] eq $b[$tmp[$z + 1]]) {
            $note .= "$tmp[$z+1]:$b[$tmp[$z + 1]] -> $tmp[$z]:$b[$tmp[$z]]\t";
            $last_moved = $tmp[$z+1];
            my $n = $b[$tmp[$z]] * 2;

            $score += $n;
            $b[$tmp[$z]] = $n;
            $b[$tmp[$z + 1]]  = 0;
         }
         print "combine iter:$z col:$u tile:$tmp[$z] : {$b[$tmp[$z]]}  ** $note\n" if ($DEBUG);
      }
   }
   &shift_tiles(\@b,$mv,1);
}

sub shift_tiles {
   my $aref = shift;
   my $mv = shift;
   my $last_run = shift;

   my @b = @{$aref};

   if(!defined($last_run)) { $last_run = 0; } #used for loop control
   while((my($u,$val))=each(%{$place{$mv}})) { 
      my @tmp = @$val;
      my $ph = 0;
      ### SHIFT ALL TILES
      for(my $z = 0; $z <=$#tmp; $z++) {
         my $note = '';
         if($b[$tmp[$z]] == 0) {
            $ph++;
            next;
         } 

         if ($ph != 0) {
            $note .= "mv:$tmp[$z] -> $tmp[$z - $ph ]\t";
            $b[$tmp[$z - $ph]] =  $b[$tmp[$z]];
            $b[$tmp[$z]] = 0;
         }

         print "shift: iter:$z col:$u tile:$tmp[$z] : {$b[$tmp[$z]]} blank:$ph ** $note\n" if ($DEBUG);
      }
      ### END SHIFT ALL TILES
   }
   if($last_run == 1) {
      return @b;
   } else {
      &combine_tiles(\@b,$mv);
   }
}

sub menu {
   my $key = &readkey;
   print "You Chose: " . $key . "\n";
   return $key ;
}

sub readkey {
   ReadMode('cbreak');
   my $key = ReadKey(0);
   ReadMode('normal');
   return $key;
}

sub flip {

   my $flip = int(rand(100));
   print "F:$flip\n" if ($DEBUG > 2);
   if($flip < $two_odds) {
      return 2;
   } else {
      return 4;
   }
   return "99";
}

sub r {
   my $val = int(rand($arr_size + 1));
   return $val ;
}

sub  arr_out  {
   my @b = @_;
   my @tmp;
   my $width = 0;
   binmode(STDOUT, ":utf8");
   my $cols = [];
   foreach(1 .. $square_size) { push($cols,"-$_-") } 
   my $t = Text::ANSITable->new(columns => $cols);
   $t->border_style('Default::bold'); 
   $t->show_row_separator(1);
   $t->cell_align('middle');
   $t->cell_valign('middle');
   $t->show_header(0);

   $t->cell_fgcolor('000000');

   $t->cell_bgcolor(
      sub {
         my ($self, %args) = @_;
         my $val = $self->get_cell($args{row_num},$args{col_num});
         if($val == 0) { return '000000'; }
         if($val == 2) { return 'FFFFFF00'; }
         if($val == 4) { return 'FFba00'; }
         if($val == 8) { return 'FF9e00'; }
         if($val == 16) { return 'ff7a00'; }
         if($val == 32) { return 'ff5a00'; }
         if($val == 64) { return 'ff3a00'; }
         if($val == 128) { return 'ff1a00'; }
         if($val == 256) { return 'FF0000'; }
         if($val == 512) { return 'bc0000'; }
         if($val == 1024) { return 'bc0010'; }
         if($val == 2048) { return 'bc0030'; }
         if($val == 4096) { return 'bc0090'; }
         if($val == 8192) { return 'bc00a0'; }
         if($val == 16384) { return 'bc00c0'; }
         if($val == 32768) { return 'bc00f0'; }
         if($val == 65536) { return 'b400f0'; }
         if($val == 131072) { return 'ac00f0'; }
         if($val == 262144) { return 'a400f0'; }
         if($val == 524288) { return '9c00f0'; }
         if($val == 1048576) { return '9400f0'; }
         if($val == 2097152) { return '8c00f0'; }
         if($val == 4194304) { return '8400f0'; }
         if($val == 8388608) { return '7c00f0'; }
         if($val == 16777216) { return '7400f0'; }
         return undef;
      }
   );

   foreach(0 .. $arr_size) {
      my $mod = int(($_ % $square_size) + 1);
      my $len = 0;
      $len =  length($b[$_]) ;
      if( $len > $width) { $width = $len; }

      push(@tmp,$b[$_]);
      if($mod == $square_size) {
         $t->add_row([@tmp]) ;
         @tmp = ();
      }
   }
   $t->cell_width($width);
   $t->cell_pad(0);
   $t->cell_vpad(0);
   print $t->draw;
}


sub flip_test {
   my $a = 0;
   my $b = 0;
   my $c = 0;
   my $d = 0;
   foreach(1 .. 10000)  {
      $a++;
      my $flip = &flip;
      if($flip == 2) { $b++; }
      elsif ($flip == 4) { $c++; }
      else { $d++; }
   }
   
   print "total: $a 2:$b 4:$c other:$d - ratio:2=" . int($b/$a * 100) .  "% ratio:4=" . int($c/$a * 100) . "%\n";
}

sub test_ranking {
   my @tests;
   my @sort_order = &sort_order;
   @b = qw(
      0  0  0  0
      0  0  0  0 
      0  0  0  0
      0  0  2  2
      ) ;
   push(@tests,[@b]);

   @b = qw(
      0  0  0  0
      0  0  0  4 
      0  0  0  0
      0  0  0  2
      ) ;
   push(@tests,[@b]);

   @b = qw(
      0  0  0  0
      0  0  0  0
      0  0  0  2
      0  0  0  2
      );
   push(@tests,[@b]);
   
   foreach(@tests) {
      my @a = @{$_};
      my $total = &arr_rank(\@sort_order,\@a);
      &arr_out(@a);
      print $total . "\n";
   }
   exit;
}
