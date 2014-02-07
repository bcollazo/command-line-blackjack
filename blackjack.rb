# CONSTANTS
CARDS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
CARD_VALUES = {"A" => 11, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "6" => 6, "7" => 7, "8" => 8, "9" => 9, "10" => 10, "J" => 10, "Q" => 10, "K" => 10}
NUM_DECKS = 6
STARTING_MONEY = 1000

# Game class
class Game
	attr_accessor :players, :dealers_hand

	# Initializes game
	def initialize
		# Shuffle decks
		@shoe = CARDS*4*NUM_DECKS
		@shoe.shuffle!

		# Ask for num_players
		input = 0
		while(input <= 0)
			puts "How many players? Please enter an integer greater than 0."
			input = gets.chomp.to_i
		end
		num_players = input

		# Init players
		@players = []
		(1..num_players).each do |i|
			@players.push(Player.new(i, STARTING_MONEY, self))
		end
	end

	# Draws a new card from shoe or resets shoe
	def new_card
		if @shoe.count <= 0
			@shoe = CARDS*4*NUM_DECKS
			@shoe.shuffle!
		end
		return @shoe.pop
	end

	# Deals new cards for players and dealer.
	def deal_cards
		@dealers_hand = Hand.new([new_card, new_card])
		@players.each do |p|
			p.hands = [Hand.new([new_card, new_card])]
		end
	end

	# Strategy is: hits on 16s, stays on 17s
	def dealer_plays
		puts "Dealer plays..."
		while (@dealers_hand.value <= 16)
			@dealers_hand.add(new_card)
		end
	end

	# Goes through one iteration of a round
	def play_round
		puts "===== Start of Round ====="
		deal_cards

		# Ask for bets
		@players.each do |player|
			player.get_bet
		end

		print_state

		# Ask for play
		@players.each do |player|
			player.play_turn
			puts "-----\n"
		end

		dealer_plays

		# Show Results
		puts "\n==== Round Results ===="
		puts "Dealer's Hand: "+@dealers_hand.to_s

		# Evaluate play for each player
		evaluate_round

		# Eliminate players if money <= 0
		@players.delete_if do |p|
			if p.money <= 0
				puts "Player "+p.id.to_s+" eliminated."
				true
			end
		end

		puts "===== End of Round =====\n\n"
	end

	def evaluate_round
		@players.each do |player|
			puts "Player "+player.id.to_s+ " outcome:"
			# Eval each hand
			(0..player.hands.count-1).each do |i|
				hand = player.hands[i]
				if hand.surrended
					player.money -= hand.bet
					puts "Player "+player.id.to_s+" losed hand "+i.to_s+" by Surrender."
				else
					eval_hand(@dealers_hand.value, player, i)
				end
			end
		end
	end

	# Main method to start playing a game.
	def play
		while (@players.count >= 1)
			play_round
			puts "Press ENTER to play next round."
			gets
		end
		puts "========== END OF GAME ==========="
		puts "\tThanks for playing!"
	end

	# Could'nt think of a better way to grade them than going almost case by case
	# maybe there is an invariant of this grading that makes it simpler.
	def eval_hand(dealers_value, p, i)
		p.show_hand(i)
		hand = p.hands[i]
		if hand.is_busted
			# Lose, even if dealer busts
			p.money -= hand.bet
			puts "\tYou lose "+hand.bet.to_s+" chips."
		elsif hand.is_blackjack
			if dealers_value == 21
				# Tie
				puts "\tTie"
			else
				# Win
				p.money += hand.bet # Assuming 1:1 payout
				puts "\tYou win "+hand.bet.to_s+" chips.  Current Money: "+p.money.to_s
			end
		else # Normal play
			if dealers_value > 21
				# Win, dealer busts
				p.money += hand.bet
				puts "\tDealer Bust"
				puts "\tYou win "+hand.bet.to_s+" chips.  Current Money: "+p.money.to_s
				return
			end
			if dealers_value == 21
				# Lose
				p.money -= hand.bet
				puts "\tDealer BlackJack"
				puts "\tYou lose "+hand.bet.to_s+" chips."
				return
			end
			value = hand.value
			if value > dealers_value
				# Win
				p.money += hand.bet
				puts "\tYou win "+hand.bet.to_s+" chips.  Current Money: "+p.money.to_s
			elsif value == dealers_value
				# Tie
				puts "\tTie"
			else
				# Lose
				p.money -= hand.bet
				puts "\tDealer wins"
				puts "\tYou lose "+hand.bet.to_s+" chips."
			end
		end
	end

	# Prints state of game
	def print_state
		puts "--------------------------"
		puts "Dealer's Hand: [\""+@dealers_hand.cards[0].to_s+"\", ?]"
		@players.each do |p|
			p.show_hand(0)
			puts "\tMoney: $"+p.money.to_s+"\tBet: $"+p.hands[0].bet.to_s
		end
		puts "--------------------------\n\n"
	end
end

# Player class.
class Player
	attr_accessor :id, :money, :hands

	# Initializes player with an id number, some money and empty hand
	def initialize(id, money, game)
		@money = money
		@id = id
		@hands = []
		@game = game
	end

	# Asks the player for a initial bet
	def get_bet
		puts "Player "+@id.to_s+ ", what is your bet?"
		bet = gets.chomp.to_i
		while (bet <= 0 || bet > @money)
			puts "Please enter a positive integer amount that you have."
			bet = gets.chomp.to_i
		end
		@hands[0].bet = bet
	end

	def get_decision(hand)
		puts "Type an action and press Enter:"
		if hand.cards.count > 2
			puts "(H=Hit, S=Stand, U=Surrender)"
			decision = gets.chomp.capitalize
			while not (["H", "S", "U"].include?decision) # Clean bad inputs
				puts "Please write a letter from H, S, and U."
				decision = gets.chomp.capitalize
			end
		else #If first turn...
			puts "(H=Hit, S=Stand, D=Double Down, P=Split, U=Surrender)"
			decision = gets.chomp.capitalize
			while not (["H", "S", "D", "P", "U"].include?decision) # Clean bad inputs
				puts "Please write a letter from H, S, D, P and U."
				decision = gets.chomp.capitalize
			end
		end
		return decision.capitalize
	end

	# Interacts with player to get play for all hands
	def play_turn
		while (not done)
			@hands.each do |hand|
				# Only consider active hands and play one to completion
				while (hand.active)

					puts "Player "+@id.to_s+"'s hand: "+hand.to_s

					if hand.is_blackjack
						puts "BLACKJACK!"
						hand.active = false
						break
					end
			
					# Gets decision
					decision = get_decision(hand)

					if decision == "H"
						puts "Hit"
						hand.add(@game.new_card)
					elsif decision == "S"
						puts "Stand"
						hand.active = false
					elsif decision == "D"
						puts "Double Down"
						if @money - hands.collect{|x| x.bet}.inject{|sum, x| sum+x} < hand.bet # Money left by subtracting all active bets
							puts "Not enough money to double down."
							next
						end
						hand.add(@game.new_card)
						hand.bet *= 2
						hand.active = false
					elsif decision == "P"
						puts "Split"
						if @money - hands.collect{|x| x.bet}.inject{|sum, x| sum+x} < hand.bet
							puts "Not enough money to split."
						elsif not hand.can_split
							puts "Can't split a "+hand.to_s+"."
						else
							split = Hand.new([hand.cards[1], @game.new_card])
							split.bet = hand.bet
							hand.cards[1] = @game.new_card
							puts "Splitted into "+hand.to_s+ " and "+split.to_s
							@hands.push(split)
						end
					elsif decision == "U"
						puts "Surrender"
						hand.surrended = true
						hand.active = false
					end
				end
			end
		end
	end

	# Prints hand i
	def show_hand(i)
		puts "Player "+@id.to_s+" hand "+i.to_s+": "+@hands[i].to_s
	end

	# Boolean on whether player is done with his turn and has no active hands
	def done
		@hands.each do |hand|
			if hand.active
				return false
			end
		end
		return true
	end
end


# Hand class.  Contains bet and status associated with a hand.
class Hand
	attr_accessor :cards, :bet, :surrended, :active
	
	def initialize(cards)
		@cards = cards
		@bet = 0
		@surrended = false
		@active = true
	end

	# Computes the value of a given hand
	def value
		total = 0
		@cards.each do |c|
			total += CARD_VALUES[c]
		end
		if total > 21 # Check for A's that are valued as 11 and change to 1
			c = @cards.count("A")
			while c > 0
				total -= 10
				if total <= 21
					break
				end
				c -= 1
			end
		end
			
		return total
	end

	# Adds card to hand.
	def add(card)
		@cards.push(card)
		puts @cards.to_s
		if is_busted	
			puts "Busted!"
			@active = false
		end
	end

	def is_blackjack
		return value == 21
	end

	def is_busted
		return value > 21
	end

	def can_split
		return (@cards.count == 2) && (CARD_VALUES[@cards[0]] == CARD_VALUES[@cards[1]])
	end

	def to_s
		return "Hand("+@cards.to_s+")"
	end
end


## Play a game:
puts "Welcome to BOCS's Blackjack!"
puts "\tby Bryan Collazo\n\n"


g = Game.new
g.play


