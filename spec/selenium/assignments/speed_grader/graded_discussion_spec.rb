# frozen_string_literal: true

#
# Copyright (C) 2024 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
require_relative "../../common"

describe "Screenreader Gradebook grading" do
  include_context "in-process server selenium tests"
  context "checkpoints" do
    before do
      Account.site_admin.enable_feature! :discussion_checkpoints
      Account.site_admin.enable_feature!(:react_discussions_post)

      @teacher = course_with_teacher_logged_in(active_course: true, active_all: true, name: "teacher").user
      @student1 = student_in_course(course: @course, name: "student", active_all: true).user
      @student2 = student_in_course(course: @course, name: "student2", active_all: true).user
      @course.root_account.enable_feature!(:discussion_checkpoints)

      @checkpointed_discussion = DiscussionTopic.create_graded_topic!(course: @course, title: "Checkpointed Discussion")
      @checkpointed_assignment = @checkpointed_discussion.assignment

      Checkpoints::DiscussionCheckpointCreatorService.call(
        discussion_topic: @checkpointed_discussion,
        checkpoint_label: CheckpointLabels::REPLY_TO_TOPIC,
        dates: [{ type: "everyone", due_at: 2.days.from_now }],
        points_possible: 5
      )

      Checkpoints::DiscussionCheckpointCreatorService.call(
        discussion_topic: @checkpointed_discussion,
        checkpoint_label: CheckpointLabels::REPLY_TO_ENTRY,
        dates: [{ type: "everyone", due_at: 5.days.from_now }],
        points_possible: 15,
        replies_required: 3
      )

      3.times do |i|
        entry = @checkpointed_discussion.discussion_entries.create!(user: @student1, message: " reply to topic i#{i} ")
        @checkpointed_discussion.discussion_entries.create!(user: @student2, message: " reply to entry i#{i} ", root_entry_id: entry.id, parent_id: entry.id)
      end

      20.times do |k|
        entry = @checkpointed_discussion.discussion_entries.create!(user: @teacher, message: " reply to topic k#{k} ")
        @checkpointed_discussion.discussion_entries.create!(user: @student1, message: " reply to entry k#{k} ", root_entry_id: entry.id, parent_id: entry.id)
      end

      3.times do |j|
        entry = @checkpointed_discussion.discussion_entries.create!(user: @student2, message: " reply to topic j#{j} ")
        @checkpointed_discussion.discussion_entries.create!(user: @student1, message: " reply to entry j#{j} ", root_entry_id: entry.id, parent_id: entry.id)
      end
      @entry = DiscussionEntry.where(message: " reply to topic j2 ").first
    end

    it "can cycle next student entry" do
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@checkpointed_assignment.id}&student_id=#{@student2.id}&entry_id=#{@entry.id}"

      3.times do |i|
        in_frame("speedgrader_iframe") do
          in_frame("discussion_preview_iframe") do
            expect(f("div[data-testid='isHighlighted']").text).to include(@student2.name)
            expect(f("div[data-testid='isHighlighted']").text).to include("reply to topic j#{2 - i}")
            # page 1 is selected
            expect(f("body").text).to include("reply to topic j2")
            expect(f("body").text).to_not include("reply to topic i0")
          end
        end
        f("button[data-testid='discussions-next-reply-button']").click
        wait_for_ajaximations
      end

      3.times do |i|
        in_frame("speedgrader_iframe") do
          in_frame("discussion_preview_iframe") do
            expect(f("div[data-testid='isHighlighted']").text).to include(@student2.name)
            expect(f("div[data-testid='isHighlighted']").text).to include("reply to entry i#{2 - i}")
            # page 2 is selected
            expect(f("body").text).to include("reply to topic i0")
            expect(f("body").text).to_not include("reply to topic j2")
          end
        end
        f("button[data-testid='discussions-next-reply-button']").click
        wait_for_ajaximations
      end

      # this means it cycles
      in_frame("speedgrader_iframe") do
        in_frame("discussion_preview_iframe") do
          expect(f("div[data-testid='isHighlighted']").text).to include(@student2.name)
          expect(f("div[data-testid='isHighlighted']").text).to include("reply to topic j2")
          # page 1 is selected
          expect(f("body").text).to include("reply to topic j2")
          expect(f("body").text).to_not include("reply to topic i0")
        end
      end
    end

    it "can cycle previous student entry" do
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@checkpointed_assignment.id}&student_id=#{@student2.id}&entry_id=#{@entry.id}"

      in_frame("speedgrader_iframe") do
        in_frame("discussion_preview_iframe") do
          expect(f("div[data-testid='isHighlighted']").text).to include(@student2.name)
          expect(f("div[data-testid='isHighlighted']").text).to include("reply to topic j2")
          # page 1 is selected
          expect(f("body").text).to include("reply to topic j2")
          expect(f("body").text).to_not include("reply to topic i0")
        end
      end
      f("button[data-testid='discussions-previous-reply-button']").click
      wait_for_ajaximations

      3.times do |i|
        in_frame("speedgrader_iframe") do
          in_frame("discussion_preview_iframe") do
            expect(f("div[data-testid='isHighlighted']").text).to include(@student2.name)
            expect(f("div[data-testid='isHighlighted']").text).to include("reply to entry i#{i}")
            # page 2 is selected
            expect(f("body").text).to include("reply to topic i0")
            expect(f("body").text).to_not include("reply to topic j2")
          end
        end
        f("button[data-testid='discussions-previous-reply-button']").click
        wait_for_ajaximations
      end

      # the last one prooves it can cycle
      3.times do |i|
        in_frame("speedgrader_iframe") do
          in_frame("discussion_preview_iframe") do
            expect(f("div[data-testid='isHighlighted']").text).to include(@student2.name)
            expect(f("div[data-testid='isHighlighted']").text).to include("reply to topic j#{i}")
            # page 1 is selected
            expect(f("body").text).to include("reply to topic j2")
            expect(f("body").text).to_not include("reply to topic i0")
          end
        end
        f("button[data-testid='discussions-previous-reply-button']").click
        wait_for_ajaximations
      end
    end
  end
end
