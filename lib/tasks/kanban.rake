# frozen_string_literal: true

namespace :kanban do
  # Uso:
  #   bundle exec rails "kanban:seed_default[ACCOUNT_ID]"
  desc 'Cria Pipeline e Stages padrão para a conta informada'
  task :seed_default, %i[account_id] => :environment do |_, args|
    unless args[:account_id].present?
      puts 'Informe ACCOUNT_ID. Ex: bundle exec rails "kanban:seed_default[2]"'
      exit(1)
    end

    account = Account.find(args[:account_id])
    puts "➡️  Conta: #{account.id} - #{account.name}"

    pipeline = account.deal_pipelines.find_or_create_by!(name: 'Padrão') do |p|
      p.is_default = true
      p.position = 1
    end
    puts "✅ Pipeline: #{pipeline.id} - #{pipeline.name}"

    stages = [
      { name: 'Novo',          position: 1, probability: 10 },
      { name: 'Contato Feito', position: 2, probability: 30 },
      { name: 'Proposta',      position: 3, probability: 60 },
      { name: 'Fechamento',    position: 4, probability: 90 },
      { name: 'Ganho',         position: 5, probability: 100, win_stage: true },
      { name: 'Perdido',       position: 6, probability: 0,   lose_stage: true }
    ]

    stages.each do |attrs|
      stage = pipeline.deal_stages.find_or_create_by!(name: attrs[:name], account_id: account.id) do |s|
        s.position    = attrs[:position]
        s.probability = attrs[:probability]
        s.win_stage   = attrs[:win_stage] || false
        s.lose_stage  = attrs[:lose_stage] || false
      end
      puts "  • Stage: #{stage.id} - #{stage.name} (#{stage.probability}%)"
    end

    puts "🎯 Pronto! Pipeline + estágios padrão criados/garantidos."
  end
end
